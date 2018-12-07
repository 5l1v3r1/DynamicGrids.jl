"""
A model contains all the information required to run a rule in a cellular
simulation, given an initialised array. Models can be chained together in any order.

The output of the rule for an AbstractModel is written to the current cell in the grid.
"""
abstract type AbstractModel end

"""
An abstract type for models that do not write to every cell of the grid, for efficiency.

There are two main differences with `AbstractModel`. AbstractPartialModel requires
initialisation of the destination array before each timestep, and the output of
the rule is not written to the grid but done manually.
"""
abstract type AbstractPartialModel <: AbstractModel end


abstract type AbstractNeighborhoodModel <: AbstractModel end
abstract type AbstractPartialNeighborhoodModel <: AbstractPartialModel end


"""
Singleton types for choosing the grid overflow rule used in
[`inbounds`](@ref). These determine what is done when a neighborhood
or jump extends outside of the grid.
"""
abstract type AbstractOverflow end
"Wrap cords that overflow to the opposite side"
struct Wrap <: AbstractOverflow end
"Skip coords that overflow boundaries"
struct Skip <: AbstractOverflow end

" A mutable container for models. 
This allows updating of immutable values for live control, such as with 
BlinkOutput, while keeping the core model immutable for GPU compatability."
mutable struct Models{M,C<:Number} 
    models::M
    cellsize::C
    Models(args...; cellsize=1) = new{typeof(args), typeof(cellsize)}(args, cellsize)
end

struct FrameData{A,C,T,M} 
    source::A
    dest::A
    cellsize::C
    t::T
    modelmem::M
end

struct NieghborhoodMem{E,L}
    extsource::E 
    extdest::E 
    loc::L
end