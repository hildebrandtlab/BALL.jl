export
    Nucleotide,
    NucleotideTable,
    nucleotide_by_idx,
    nucleotides,
    nnucleotides,
    parent_nucleotide

"""
    $(TYPEDEF)

Mutable representation of an individual nucleotide in a system.

# Public fields
 - `idx::Int`
 - `number::Int`
 - `name::String`

# Private fields
 - `properties::Properties`
 - `flags::Flags`
 - `molecule_idx::Int`
 - `chain_idx::Int`

# Constructors
```julia
Nucleotide(
    chain::Chain{T},
    number::Int;
    # keyword arguments
    name::String = "",
    properties::Properties = Properties(),
    flags::Flags = Flags()
)
```
Creates a new `Nucleotide{T}` in the given chain.
"""
const Nucleotide{T} = AtomContainer{T, _NucleotideTableRow}

@inline function Nucleotide(
    chain::Chain{T},
    number::Int;
    kwargs...
) where T
    sys = parent(chain)
    idx = _next_idx(sys)
    push!(sys._nucleotides, idx, number, chain.molecule_idx, chain.idx; kwargs...)
    nucleotide_by_idx(sys, idx)
end

"""
    $(TYPEDEF)

Tables.jl-compatible representation of system nucleotides (or a subset thereof). Nucleotide tables can be
generated using [`nucleotides`](@ref) or filtered from other nucleotide tables (via `Base.filter`).

# Public columns
 - `idx::AbstractVector{Int}`
 - `number::AbstractVector{Int}`
 - `name::AbstractVector{String}`

# Private columns
 - `properties::AbstractVector{Properties}`
 - `flags::AbstractVector{Flags}`
 - `molecule_idx::AbstractVector{Int}`
 - `chain_idx::AbstractVector{Int}`
"""
const NucleotideTable{T} = SystemComponentTable{T, Nucleotide{T}}

@inline function _filter_nucleotides(f::Function, sys::System{T}) where T
    NucleotideTable{T}(sys, _filter_idx(f, sys._nucleotides))
end

@inline _table(sys::System{T}, ::Type{Nucleotide{T}}) where T = sys._nucleotides

@inline function _hascolumn(::Type{<: Nucleotide}, nm::Symbol)
    nm in _nucleotide_table_cols_set || nm in _nucleotide_table_cols_priv
end

@inline parent_molecule(nuc::Nucleotide) = molecule_by_idx(parent(nuc), nuc.molecule_idx)
@inline parent_chain(nuc::Nucleotide) = chain_by_idx(parent(nuc), nuc.chain_idx)

@doc raw"""
    parent_nucleotide(::Atom)

Returns the `Nucleotide{T}` containing the given atom. Returns `nothing` if no such nucleotide exists.
""" parent_nucleotide

"""
    $(TYPEDSIGNATURES)

Returns the `Nucleotide{T}` associated with the given `idx` in `sys`. Throws a `KeyError` if no such
nucleotide exists.
"""
@inline function nucleotide_by_idx(sys::System{T}, idx::Int) where T
    Nucleotide{T}(sys, _row_by_idx(sys._nucleotides, idx))
end

"""
    nucleotides(::Chain)
    nucleotides(::Molecule)
    nucleotides(::System)

Returns a `NucleotideTable{T}` containing all nucleotides of the given atom container.

# Supported keyword arguments
 - `molecule_idx::MaybeInt = nothing`
 - `chain_idx::MaybeInt = nothing`
All keyword arguments limit the results to nucleotides matching the given IDs. Keyword arguments set to
`nothing` are ignored.
"""
function nucleotides(sys::System{T};
    molecule_idx::MaybeInt = nothing,
    chain_idx::MaybeInt = nothing
) where T
    isnothing(molecule_idx) && isnothing(chain_idx) && return NucleotideTable{T}(sys, sys._nucleotides.idx)
    _filter_nucleotides(nuc ->
        (isnothing(molecule_idx) || nuc.molecule_idx == something(molecule_idx)) &&
        (isnothing(chain_idx)    || nuc.chain_idx    == something(chain_idx)),
        sys
    )
end

"""
    nnucleotides(::Chain)
    nnucleotides(::Molecule)
    nnucleotides(::System)

Returns the number of nucleotides in the given atom container.

# Supported keyword arguments
See [`nucleotides`](@ref)
"""
@inline function nnucleotides(sys::System; kwargs...)
    length(nucleotides(sys; kwargs...))
end

#=
    Nucleotides
=#
@inline nucleotides(mol::Molecule; kwargs...) = nucleotides(parent(mol); molecule_idx = mol.idx, kwargs...)
@inline nnucleotides(mol::Molecule; kwargs...) = nnucleotides(parent(mol); molecule_idx = mol.idx, kwargs...)

#=
    Chain nucleotides
=#
@inline nucleotides(chain::Chain; kwargs...) = nucleotides(parent(chain); chain_idx = chain.idx, kwargs...)
@inline nnucleotides(chain::Chain; kwargs...) = nnucleotides(parent(chain); chain_idx = chain.idx, kwargs...)

"""
    push!(::Chain{T}, ::Nucleotide{T})

Creates a copy of the given nucleotide in the given chain. The new nucleotide is automatically assigned a
new `idx`.
"""
@inline function Base.push!(chain::Chain{T}, nuc::Nucleotide{T}) where T
    Nucleotide(chain, nuc.number;
        name = nuc.name,
        properties = nuc.properties,
        flags = nuc.flags
    )
    chain
end

#=
    Nucleotide atoms
=#
@inline atoms(nuc::Nucleotide; kwargs...) = atoms(parent(nuc); nucleotide_idx = nuc.idx, kwargs...)
@inline natoms(nuc::Nucleotide; kwargs...) = natoms(parent(nuc); nucleotide_idx = nuc.idx, kwargs...)

@inline function Atom(nuc::Nucleotide, number::Int, element::ElementType; kwargs...)
    Atom(parent(nuc), number, element;
        molecule_idx = nuc.molecule_idx,
        chain_idx = nuc.chain_idx,
        nucleotide_idx = nuc.idx,
        kwargs...
    )
end

@inline function Base.push!(nuc::Nucleotide{T}, atom::Atom{T}; kwargs...) where T
    push!(parent(nuc), atom;
        molecule_idx = nuc.molecule_idx,
        chain_idx = nuc.chain_idx,
        nucleotide_idx = nuc.idx,
        kwargs...
    )
    nuc
end

#=
    Nucleotide bonds
=#
@inline bonds(nuc::Nucleotide; kwargs...) = bonds(parent(nuc); nucleotide_idx = nuc.idx, kwargs...)
@inline nbonds(nuc::Nucleotide; kwargs...) = nbonds(parent(nuc); nucleotide_idx = nuc.idx, kwargs...)

# TODO: we should come up with a better test than just checking the name
is_nucleotide(name::String) = name ∈ ["A", "C", "G", "T", "U", "I", "DA", "DC", "DG", "DT", "DU", "DI"]
