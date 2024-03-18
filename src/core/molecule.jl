export
    AbstractMolecule,
    Molecule,
    MoleculeTable,
    molecule_by_idx,
    molecules,
    nmolecules,
    parent_molecule

"""
    $(TYPEDEF)

Abstract base type for all molecules.
"""
abstract type AbstractMolecule{T} <: AbstractAtomContainer{T} end

"""
    $(TYPEDEF)

Mutable representation of an individual molecule in a system.

# Public fields
 - `idx::Int`
 - `name::String`

# Private fields
 - `properties::Properties`
 - `flags::Flags`

# Constructors
```julia
Molecule(
    sys::System{T};
    # keyword arguments
    name::String = "",
    properties::Properties = Properties(),
    flags::Flags = Flags()
)
```
Creates a new `Molecule{T}` in the given system.

```julia
Molecule(;
    #keyword arguments
    name::String = "",
    properties::Properties = Properties(),
    flags::Flags = Flags()
)
```
Creates a new `Molecule{Float32}` in the default system.
"""
@auto_hash_equals struct Molecule{T} <: AbstractMolecule{T}
    _sys::System{T}
    _row::_MoleculeTableRow
end

@inline function Molecule(
    sys::System{T};
    kwargs...
) where T
    idx = _next_idx(sys)
    push!(sys._molecules, idx; kwargs...)
    molecule_by_idx(sys, idx)
end

@inline function Molecule(; kwargs...)
    Molecule(default_system(); kwargs...)
end

"""
    $(TYPEDEF)

Tables.jl-compatible representation of system molecules (or a subset thereof). Molecule tables can be
generated using [`molecules`](@ref) or filtered from other molecule tables (via `Base.filter`).

# Public columns
 - `idx::AbstractVector{Int}`
 - `name::AbstractVector{String}`

# Private columns
 - `properties::AbstractVector{Properties}`
 - `flags::AbstractVector{Flags}`
"""
const MoleculeTable{T} = SystemComponentTable{T, Molecule{T}}

@inline function _filter_molecules(f::Function, sys::System{T}) where T
    MoleculeTable{T}(sys, _filter_idx(f, sys._molecules))
end

@inline _table(sys::System{T}, ::Type{Molecule{T}}) where T = sys._molecules

@inline function _hascolumn(::Type{<: Molecule}, nm::Symbol)
    nm in _molecule_table_cols_set || nm in _molecule_table_cols_priv
end

@inline function Base.getproperty(mol::Molecule, name::Symbol)
    hasfield(typeof(mol), name) && return getfield(mol, name)
    getproperty(getfield(mol, :_row), name)
end

@inline function Base.setproperty!(mol::Molecule, name::Symbol, val)
    hasfield(typeof(mol), name) && return setfield!(mol, name, val)
    setproperty!(getfield(mol, :_row), name, val)
end

@inline Base.show(io::IO, ::MIME"text/plain", mol::Molecule) = show(io, mol)
@inline function Base.show(io::IO, mol::Molecule)
    print(io, "$(typeof(mol)): ")
    show(io, NamedTuple(mol._row))
end

@inline Base.parent(mol::Molecule) = mol._sys
@inline parent_system(mol::Molecule) = parent(mol)

@doc raw"""
    parent_molecule(::Atom)
    parent_molecule(::Chain)
    parent_molecule(::Fragment)
    parent_molecule(::Nucleotide)
    parent_molecule(::Residue)

Returns the `Molecule{T}` containing the given object. Returns `nothing` if no such molecule exists.
""" parent_molecule

"""
    push!(::System{T}, ::Molecule{T})

Creates a copy of the given molecule in the given system. The new molecule is automatically assigned a
new `idx`.
"""
@inline function Base.push!(sys::System{T}, mol::Molecule{T}) where T
    Molecule(sys;
        name = mol.name,
        properties = mol.properties,
        flags = mol.flags
    )
    sys
end

"""
    $(TYPEDSIGNATURES)

Returns the `Molecule{T}` associated with the given `idx` in `sys`. Throws a `KeyError` if no such
molecule exists.
"""
@inline function molecule_by_idx(sys::System{T}, idx::Int) where T
    Molecule{T}(sys, _row_by_idx(sys._molecules, idx))
end

"""
    $(TYPEDSIGNATURES)

Returns a `MoleculeTable{T}` containing all molecules of the given system.
"""
@inline function molecules(sys::System{T}) where T
    MoleculeTable{T}(sys, sys._molecules.idx)
end

"""
    $(TYPEDSIGNATURES)

Returns the number of molecules in the given system.
"""
function nmolecules(sys::System)
    length(sys._molecules)
end

#=
    Molecule atoms
=#
@inline atoms(mol::Molecule; kwargs...) = atoms(parent(mol); molecule_idx = mol.idx, kwargs...)
@inline natoms(mol::Molecule; kwargs...) = natoms(parent(mol); molecule_idx = mol.idx, kwargs...)

@inline function Atom(mol::Molecule, number::Int, element::ElementType; kwargs...)
    Atom(parent(mol), number, element; molecule_idx = mol.idx, kwargs...)
end

@inline function Base.push!(mol::Molecule{T}, atom::Atom{T}; kwargs...) where T
    push!(parent(mol), atom; molecule_idx = mol.idx, kwargs...)
    mol
end

#=
    Molecule bonds
=#
@inline bonds(mol::Molecule; kwargs...) = bonds(parent(mol); molecule_idx = mol.idx, kwargs...)
@inline nbonds(mol::Molecule; kwargs...) = nbonds(parent(mol); molecule_idx = mol.idx, kwargs...)
