"""
sim!(output, ruleset; init=nothing, tstpan=(1, length(output)),
     fps=fps(output), simdata=nothing, nreplicates=nothing)

Runs the whole simulation, passing the destination aray to
the passed in output for each time-step.

### Arguments
- `output`: An [Output](@ref) to store grids or display them on the screen.
- `ruleset`: A Rule() containing one ore more [`Rule`](@ref). These will each be run in sequence.

### Keyword Arguments
- `init`: the initialisation array. If not passed, the [`Ruleset`](@ref) must contain an `init` array.
- `tspan`: a tuple holding the start and end of the timespan the simulaiton will run for.
- `fps`: the frames per second to display. Will be taken from the output if not passed in.
- `nreplicates`: the number of replicates to combine in stochastic simulations
- `simdata`: a SimData object. Keeping it between simulations can reduce memory
  allocation when that is important.
"""
sim!(output, ruleset; init=nothing, tspan=(1, length(output)), fps=fps(output),
     nreplicates=nothing, simdata=nothing) = begin
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")
    starttime = first(tspan)
    fspan = _tspan2fspan(tspan, timestep(ruleset))
    setstarttime!(output, starttime)
    # Copy the init array from the ruleset or keyword arg
    init = _chooseinit(DynamicGrids.init(ruleset), init)
    simdata = initdata!(simdata, ruleset, init, starttime, nreplicates)
    # Delete grids output by the previous simulations
    initgrids!(output, init)
    setfps!(output, fps)
    # Show the first grid
    showgrid(output, simdata, 1, starttime)
    # Let the init grid be displayed as long as a normal grid
    delay(output, 1)
    # Run the simulation
    runsim!(output, simdata, fspan)
end

_tspan2fspan(tspan, tstep) = 1:lastindex(first(tspan):tstep:last(tspan))

# Allows attaching an init array to the ruleset, but also passing in an
# alternate array as a keyword arg (which will take preference).
_chooseinit(rulesetinit, arginit) = arginit
_chooseinit(rulesetinit::Nothing, arginit) = arginit
_chooseinit(rulesetinit, arginit::Nothing) = rulesetinit
_chooseinit(rulesetinit::Nothing, arginit::Nothing) =
    error("Include an init array: either in the ruleset or with the `init` keyword")

"""
    resume!(output, ruleset; tadd=100, kwargs...)

Restart the simulation where you stopped last time. For arguments see [`sim!`](@ref).
The keyword arg `tadd` indicates the number of grid frames to add, and of course an init
array will not be accepted.
"""
resume!(output, ruleset; tstop=stoptime(output), fps=fps(output), simdata=nothing,
        nreplicates=nothing) = begin
    length(output) > 0 || error("There is no simulation to resume. Run `sim!` first")
    isrunning(output) && error("A simulation is already running in this output")
    setrunning!(output, true) || error("Could not start the simulation with this output")
    tstart = starttime(output)
    lastframe = lastindex(tstart:timestep(ruleset):stoptime(output))
    stopframe = lastindex(tstart:timestep(ruleset):tstop)
    fspan = lastframe:stopframe
    # Use the last frame of the existing simulation as the init frame
    init = output[lastframe]
    simdata = initdata!(simdata, ruleset, init, tstart, nreplicates)
    setfps!(output, fps)
    runsim!(output, simdata, fspan)
end

# run the simulation either directly or asynchronously.
runsim!(output, args...) =
    if isasync(output)
        @async simloop!(output, args...)
    else
        simloop!(output, args...)
    end

#= Loop over the selected timespan, running the ruleset and displaying the output
Operations on outputs and rulesets are allways mutable and in-place.
Operations on rules and simdata objects are functional as they are used in inner loops
where immutability improves performance. =#
simloop!(output, simdata, fspan) = begin
    settimestamp!(output, first(fspan))
    # Initialise types etc
    simdata = updatetime(simdata, 1)# |> precalcrules
    # Loop over the simulation
    for f in fspan[2:end]
        # Get a data object with updated timestep and precalculated rules
        simdata = updatetime(simdata, f) |> precalcrules
        # Run the ruleset and setup data for the next iteration
        simdata = sequencerules!(simdata)
        # Save/do something with the the current grid
        storegrid!(output, simdata)
        isasync(output) && yield()
        # Stick to the FPS
        delay(output, f)
        # Exit gracefully
        if !isrunning(output) || f == last(fspan)
            showgrid(output, simdata, f, currenttime(simdata))
            setrunning!(output, false)
            setstoptime!(output, currenttime(simdata))
            finalize!(output)
            break
        end
    end
    output
end

precalcrules(rule, simdata) = rule
precalcrules(simdata::SimData) =
    @set simdata.ruleset.rules = precalcrules(rules(simdata), simdata)
precalcrules(rules::Tuple, simdata) =
    (precalcrules(rules[1], simdata), precalcrules(tail(rules), simdata)...)
precalcrules(rules::Tuple{}, simdata) = ()
precalcrules(chain::Chain{R,W}, simdata) where {R,W} = begin
    ch = precalcrules(val(chain), simdata)
    Chain{R,W,typeof(ch)}(ch)
end
