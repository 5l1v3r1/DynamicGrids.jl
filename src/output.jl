"""
$(TYPEDEF)
Simulation outputs can be used interchangeably as they are decoupled 
from the simulation behaviour. Outputs should inherit from AbstractOutput.

All types extending AbstractOutput should have their own method of `update_output`.
"""
abstract type AbstractOutput end 

"""
$(TYPEDEF)
Output subtype for arrays
"""
abstract type AbstractArrayOutput <: AbstractOutput end 

(::Type{T})(init) where T <: AbstractArrayOutput = T{typeof(init)}([])

""" 
    update_output(output, frame, t, pause)
Methods that update the output with the current frame, for timestep t.
$(METHODLIST)
"""
function update_output end


"""
$(TYPEDEF)
Simple array output: creates an array of frames.
$(FIELDS)
"""
struct ArrayOutput{A} <: AbstractArrayOutput
    frames::Array{A,1}
end

""" 
$(SIGNATURES)
Copies the current frame array unchanged to the stored array 
"""
update_output(output::AbstractArrayOutput, frame, t, pause) = begin
    fr = frames(output)
    push!(fr, deepcopy(frame))
    true
end


"""
$(TYPEDEF)
An array output that is printed as asccii blocks in the REPL.
$(FIELDS)
"""
struct REPLOutput{A} <: AbstractArrayOutput
    frames::Array{A,1}
end

update_output(output::REPLOutput, frame, t, pause) = begin
    fr = frames(output)
    push!(fr, deepcopy(frame))
    Terminal.put([1,1], repl_frame(fr[end]))
    sleep(pause)
    true
end

"""
$(SIGNATURES)
Print the last frame of a simulation in the REPL.
"""
Base.show(io::IO, output::REPLOutput) = begin
    println(io, typeof(output))

    fr = frames(output)
    length(fr) == 0 && return

    print(repl_frame(fr[end]))
end

function repl_frame(frame)
    io = String("")
    for i = 1:2:size(frame, 1)
        io *= "\t"
        # Two line pers character
        for j = 1:size(frame, 2)
            top = frame[i,j] > 0.5
            bottom = frame[i+1,j] > 0.5
            if top 
                io *= bottom ? "█" : "▀"
            else
                io *= bottom ? "▄" : " "
            end
        end
        io *= "\n"
    end
    io *= "\n\n"
end

"""
$(SIGNATURES)
Converts an array to an image format.
"""
process_image(frame, output) = convert(Array{UInt32, 2}, frame) .* 0x00ffffff


@require Tk begin
    using Cairo

    """
    $(TYPEDEF)
    Plot output live to a Tk window.
    Requires `using Tk` to be available. 
    $(FIELDS)
    """
    struct TkOutput{W,C,CR,D} <: AbstractOutput
        window::W
        canvas::C
        cr::CR
        run::D
    end

    """
        TkOutput(frame; scaling = 2)
    Constructor for TkOutput.
    - `init::AbstractArray`: the `init` array that will also be passed to sim!()
    """
    TkOutput(init; scaling = 2) = begin
        m, n = size(init)
        window = Tk.Toplevel("Cellular Automata", n, m)
        canvas = Tk.Canvas(window)
        ok = [true]
        Tk.pack(canvas, expand = true, fill = "both")
        canvas.mouse.button1press = (canvas, x, y) -> (run[1] = false)
        cr = getgc(canvas)
        scale(cr, scaling, scaling)
        TkOutput(window, canvas, cr, run)
    end

    """
    $(SIGNATURES)
    """
    function update_output(output::TkOutput, frame, t, pause)
        img = process_image(frame, output)
        set_source_surface(output.cr, CairoRGBSurface(img), 0, 0)
        paint(output.cr)
        Tk.reveal(output.canvas)
        sleep(pause)
        output.run[1]
    end
end

frames(output::AbstractArrayOutput) = output.frames

@require FileIO begin

    using FixedPointNumbers
    using Colors
    import FileIO.save

    save(filename::AbstractString, output::ArrayOutput; kwargs...) = begin
        f = frames(output)
        a = reshape(reduce(hcat, f), size(f[1])..., length(f))
        save("test.gif", vcat(frames(output)))
    end

end
