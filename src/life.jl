""" 
Rule for game-of-life style cellular automata. 
$(FIELDDOCTABLE)
"""
@description @limits @flattenable @default_kw struct Life{N,B,S} <: AbstractNeighborhoodRule
    neighborhood::N | RadialNeighborhood(1) | false | nothing | "Any AbstractNeighborhood"
    b::B | (3, 3) | true | (0, 8) | "Array, Tuple or Iterable of integers to match neighbors when cell is empty"
    s::S | (2, 3) | true | (0, 8) | "Array, Tuple or Iterable of integers to match neighbors cell is full"
end

"""
    rule(model::AbstractLife, state)

Rule for game-of-life style cellular automata. This is a demonstration of 
Cellular Automata more than a seriously optimised game of life model.


Cells becomes active if it is empty and the number of neightbors is a number in
the b array, and remains active the cell is active and the number of neightbors is
in the s array.

Returns: boolean

## Examples (gleaned from CellularAutomata.jl)

Use the arrow keys to scroll around, or zoom out if your terminal can do that!

```julia
# Life. 
init = round.(Int64, max.(0.0, rand(-3.0:0.1:1.0, 300,300)))
output = REPLOutput{:block}(init; fps=10, color=:red)
sim!(output, model, init; time=1000)

# Dimoeba
init = rand(0:1, 400, 300)
init[:, 100:200] .= 0
output = REPLOutput{:braile}(init; fps=25, color=:blue)
sim!(output, Ruleset(Life(b=(3,5,6,7,8), s=(5,6,7,8))), init; time=1000)

# Replicator
init = fill(1, 300,300)
init[:, 100:200] .= 0
init[10, :] .= 0
output = REPLOutput{:block}(init; fps=60, color=:yellow)
sim!(output, Ruleset(Life(b=(1,3,5,7), s=(1,3,5,7))), init; time=1000)
```

"""
applyrule(model::Life, data, state, index) = begin
    # Sum neighborhood
    cc = neighbors(model.neighborhood, model, data, state, index)
    # Determine next state based on current state and neighborhood total
    counts = (model.b, model.s)[state+1]
    for i = 1:length(counts)
        if counts[i] == cc
            return oneunit(state)
        end
    end
    return zero(state)
end
