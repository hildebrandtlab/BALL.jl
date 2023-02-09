using AutoHashEquals
export Atom, atoms, atoms_df, eachatom, natoms

"""
    $(TYPEDEF)

Mutable representation of an individual atom in a system.

# Fields
 - `idx::Int`
 - `number::Int`
 - `element::ElementType`
 - `name::String`
 - `atomtype::String`
 - `r::Vector3{T}`
 - `v::Vector3{T}`
 - `F::Vector3{T}`
 - `has_velocity::Bool`
 - `has_force::Bool`
 - `properties::Properties`

# Constructors
```julia
Atom(
    number::Int,
    element::ElementType,
    name::String = "",
    atomtype::String = "",
    r::Vector3{T} = Vector3{T}(0, 0, 0),
    v::Vector3{T} = Vector3{T}(0, 0, 0),
    F::Vector3{T} = Vector3{T}(0, 0, 0),
    has_velocity::Bool = false,
    has_force::Bool = false,
    properties::Properties = Properties();
    # keyword arguments
    frame_id::Int = 1
)
```
Creates a new `Atom{Float32}` in the default system.

```julia
Atom(
    sys::System{T},
    number::Int,
    element::ElementType,
    name::String = "",
    atomtype::String = "",
    r::Vector3{T} = Vector3{T}(0, 0, 0),
    v::Vector3{T} = Vector3{T}(0, 0, 0),
    F::Vector3{T} = Vector3{T}(0, 0, 0),
    has_velocity::Bool = false,
    has_force::Bool = false,
    properties::Properties = Properties();
    # keyword arguments
    frame_id::Int = 1
)
```
Creates a new `Atom{T}` in the given system.

    Atom(a::AtomTuple{T}; frame_id::Int = 1)
    Atom(sys::System{T}, a::AtomTuple{T}; frame_id::Int = 1)

Constructor variants that create a new system atom based on the given `AtomTuple{T}`. The new atom
is automatically assigned a new `idx`.
"""
@auto_hash_equals struct Atom{T}
    sys::System{T}
    row::DataFrameRow
end

function Atom(
    sys::System{T},
    number::Int,
    element::ElementType,
    name::String = "",
    atomtype::String = "",
    r::Vector3{T} = Vector3{T}(0, 0, 0),
    v::Vector3{T} = Vector3{T}(0, 0, 0),
    F::Vector3{T} = Vector3{T}(0, 0, 0),
    has_velocity::Bool = false,
    has_force::Bool = false,
    properties::Properties = Properties();
    frame_id::Int = 1,
    # private kwargs
    molecule_id::MaybeInt = missing,
    chain_id::MaybeInt = missing,
    fragment_id::MaybeInt = missing,
    nucleotide_id::MaybeInt = missing,
    residue_id::MaybeInt = missing
) where T
    idx = _next_idx(sys)
    push!(sys.atoms, (idx, number, element, name, atomtype, r, v, F, has_velocity, has_force,
        properties, frame_id, molecule_id, chain_id, fragment_id, nucleotide_id, residue_id))
    _atom_by_idx(sys, idx)
end

function Atom(
    number::Int,
    element::ElementType,
    name::String = "",
    atomtype::String = "",
    r::Vector3{Float32} = Vector3{Float32}(0, 0, 0),
    v::Vector3{Float32} = Vector3{Float32}(0, 0, 0),
    F::Vector3{Float32} = Vector3{Float32}(0, 0, 0),
    has_velocity::Bool = false,
    has_force::Bool = false,
    properties::Properties = Properties();
    kwargs...
)
    Atom(default_system(), number, element, name, atomtype, r, v, F, has_velocity, has_force,
        properties; kwargs...)
end

@inline function Atom(sys::System{T}, atom::AtomTuple{T}; kwargs...) where T
    Atom(sys, ntuple(i -> atom[i+1], length(atom) - 1)...; kwargs...)
end

@inline function Atom(t::AtomTuple{Float32}; kwargs...)
    Atom(default_system(), t; kwargs...)
end

function Base.getproperty(atom::Atom, name::Symbol)
    in(name, fieldnames(AtomTuple)) && return getproperty(getfield(atom, :row), name)
    getfield(atom, name)
end

function Base.setproperty!(atom::Atom, name::Symbol, val)
    in(name, fieldnames(AtomTuple)) && return setproperty!(getfield(atom, :row), name, val)
    setfield!(atom, name, val)
end

# TODO hide internals
@inline Base.show(io::IO, ::MIME"text/plain", atom::Atom) = show(io, getfield(atom, :row))
@inline Base.show(io::IO, atom::Atom) = show(io, getfield(atom, :row))

@inline Base.parent(atom::Atom) = atom.sys
@inline parent_system(atom::Atom) = parent(atom)

@inline function parent_molecule(atom::Atom) 
    ismissing(atom.row.molecule_id) ? nothing : _molecule_by_idx(atom.sys, atom.row.molecule_id)
end

@inline function parent_chain(atom::Atom)
    ismissing(atom.row.chain_id) ? nothing : _chain_by_idx(atom.sys, atom.row.chain_id)
end

@inline function parent_fragment(atom::Atom)
    ismissing(atom.row.fragment_id) ? nothing : _fragment_by_idx(atom.sys, atom.row.fragment_id)
end

@inline function parent_nucleotide(atom::Atom)
    ismissing(atom.row.nucleotide_id) ? nothing : _nucleotide_by_idx(atom.sys, atom.row.nucleotide_id)
end

@inline function parent_residue(atom::Atom)
    ismissing(atom.row.residue_id) ? nothing : _residue_by_idx(atom.sys, atom.row.residue_id)
end

"""
    $(TYPEDSIGNATURES)

Returns the `Atom{T}` associated with the given `idx` in `sys`.
"""
@inline function _atom_by_idx(sys::System{T}, idx::Int) where T
    @with sys.atoms begin
        Atom{T}(sys, DataFrameRow(sys.atoms, findfirst(:idx .== idx), :))
    end
end

"""
    $(TYPEDSIGNATURES)

Returns a raw `DataFrame` for all of the given system's atoms matching the given criteria (value or
`missing`). Fields given as `nothing` are ignored. The returned `DataFrame` contains all public and
private atom fields.
"""
function _atoms(sys::System{T};
    frame_id::Union{Nothing, Int} = 1,
    molecule_id::Union{Nothing, MaybeInt} = nothing,
    chain_id::Union{Nothing, MaybeInt} = nothing,
    fragment_id::Union{Nothing, MaybeInt} = nothing,
    nucleotide_id::Union{Nothing, MaybeInt} = nothing,
    residue_id::Union{Nothing, MaybeInt} = nothing
) where T
    cols = Tuple{Symbol, MaybeInt}[]
    isnothing(frame_id)      || push!(cols, (:frame_id, frame_id))
    isnothing(molecule_id)   || push!(cols, (:molecule_id, molecule_id))
    isnothing(chain_id)      || push!(cols, (:chain_id, chain_id))
    isnothing(fragment_id)   || push!(cols, (:fragment_id, fragment_id))
    isnothing(nucleotide_id) || push!(cols, (:nucleotide_id, nucleotide_id))
    isnothing(residue_id)    || push!(cols, (:residue_id, residue_id))

    get(
        groupby(sys.atoms, getindex.(cols, 1)),
        ntuple(i -> cols[i][2], length(cols)),
        view(sys.atoms, Int[], :)
    )::SubDataFrame{DataFrame, DataFrames.Index, Vector{Int}}
end

"""
    atoms(::Chain)
    atoms(::Fragment)
    atoms(::Molecule)
    atoms(::Nucleotide)
    atoms(::Protein)
    atoms(::Residue)
    atoms(::System)

Returns a `Vector{Atom{T}}` containing all atoms of the given atom container.

# Supported keyword arguments
 - `frame_id::Union{Nothing, Int} = 1`: \
Any value other than `nothing` limits the result to atoms matching this frame ID.
"""
@inline function atoms(sys::System; kwargs...)
    collect(eachatom(sys; kwargs...))
end

"""
    atoms_df(::Chain)
    atoms_df(::Fragment)
    atoms_df(::Molecule)
    atoms_df(::Nucleotide)
    atoms_df(::Protein)
    atoms_df(::Residue)
    atoms_df(::System)

Returns a `SystemDataFrame{T}` containing all atoms of the given atom container.

# Supported keyword arguments
 - `frame_id::Union{Nothing, Int} = 1`: \
Any value other than `nothing` limits the result to atoms matching this frame ID.
"""
@inline function atoms_df(sys::System{T}; kwargs...) where T
    SystemDataFrame{T}(sys, view(_atoms(sys; kwargs...), :, 1:length(fieldnames(AtomTuple{T}))))
end

"""
    eachatom(::Chain)
    eachatom(::Fragment)
    eachatom(::Molecule)
    eachatom(::Nucleotide)
    eachatom(::Protein)
    eachatom(::Residue)
    eachatom(::System)

Returns an `Atom{T}` generator for all atoms of the given atom container.

# Supported keyword arguments
 - `frame_id::Union{Nothing, Int} = 1`: \
Any value other than `nothing` limits the result to atoms matching this frame ID.

# Example
```julia
for atom in eachatom(sys)
    println(atom.name)
end
```
"""
@inline function eachatom(sys::System{T}; kwargs...) where T
    (Atom{T}(sys, row) for row in eachrow(_atoms(sys; kwargs...)))
end

"""
    natoms(::Chain)
    natoms(::Fragment)
    natoms(::Molecule)
    natoms(::Nucleotide)
    natoms(::Protein)
    natoms(::Residue)
    natoms(::System)

Returns the number of atoms in the given atom container.

# Supported keyword arguments
 - `frame_id::Union{Nothing, Int} = 1`: \
Any value other than `nothing` limits the result to atoms matching this frame ID.
"""
@inline function natoms(sys::System; kwargs...)
    nrow(_atoms(sys; kwargs...))
end

"""
    push!(::Fragment{T}, atom::AtomTuple{T})
    push!(::Molecule{T}, atom::AtomTuple{T})
    push!(::Nucleotide{T}, atom::AtomTuple{T})
    push!(::Protein{T}, atom::AtomTuple{T})
    push!(::Residue{T}, atom::AtomTuple{T})
    push!(::System{T}, atom::AtomTuple{T})

Creates a new atom in the given atom container, based on the given tuple. The new atom is
automatically assigned a new `idx`.

# Supported keyword arguments
 - `frame_id::Int = 1`
"""
function Base.push!(sys::System{T}, atom::AtomTuple{T};
    frame_id::Int = 1,
    molecule_id::MaybeInt = missing,
    chain_id::MaybeInt = missing,
    fragment_id::MaybeInt = missing,
    nucleotide_id::MaybeInt = missing,
    residue_id::MaybeInt = missing
) where T
    push!(sys.atoms, 
        (_with_idx(atom, _next_idx(sys))...,
            frame_id, molecule_id, chain_id, fragment_id, nucleotide_id, residue_id)
    )
    sys
end
