export Substructure, filter_atoms

@auto_hash_equals struct Substructure{T<:Real, A<:AbstractAtomContainer{T}} <: AbstractMolecule{T}
    name::String

    parent::A
    
    _atoms::AtomTable{T}
    _bonds::BondTable{T}
    
    properties::Properties

    function Substructure{T,A}(
        name::String,
        parent::A,
        atoms::AtomTable{T},
        bonds::BondTable{T},
        properties::Properties = parent.properties
    ) where {T<:Real, A<:AbstractAtomContainer{T}}
        new(name, parent, atoms, bonds, properties)
    end
end

@inline Substructure(
    name::String,
    parent::A,
    atoms::AtomTable{T},
    bonds::BondTable{T},
    properties::Properties = parent.properties
) where {T, A} = Substructure{Float32, typeof(parent)}(name, parent, atoms, bonds, properties)

function filter_atoms(fn, mol::AbstractAtomContainer{T}; name="", adjacent_bonds=false) where T
    atom_view = filter(fn, atoms(mol))
    idxset = Set(atom_view.idx)
    bond_view = filter(row ->
        adjacent_bonds ? row.a1 ∈ idxset || row.a2 ∈ idxset
                        : row.a1 ∈ idxset && row.a2 ∈ idxset,
        bonds(mol)
    )
    Substructure(name, mol, atom_view, bond_view)
end

function Base.copy(substruct::Substructure{T}) where T
    sys = System{T}(substruct.name)
    sys._curr_idx = sys._curr_idx

    sys.properties = copy(substruct.properties)
    sys.flags      = copy(substruct.parent.flags)

    sys._atoms = _atom_table(T, deepcopy(substruct._atoms))
    sys._bonds = _bond_table(deepcopy(substruct._bonds))

    sys._molecules   = _molecule_table(deepcopy(_molecules(substruct)))
    sys._chains      = _chain_table(deepcopy(_chains(substruct)))
    sys._fragments   = _fragment_table(deepcopy(_fragments(substruct)))
    sys._nucleotides = _nucleotide_table(deepcopy(_nucleotides(substruct)))
    sys._residues    = IndexedDataFrame(copy(_residues(substruct)))

    sys
end

"""
$(TYPEDSIGNATURES)

Returns an `AtomTable` for all of the given system's atoms matching the given criteria (value or
`missing`). Fields given as `nothing` are ignored. The returned table contains all public and
private atom fields.
"""
@inline function _atoms(substruct::Substructure{T};
    frame_id::MaybeInt = 1,
    molecule_id::Union{MaybeInt, Some{Nothing}} = nothing,
    chain_id::Union{MaybeInt, Some{Nothing}} = nothing,
    fragment_id::Union{MaybeInt, Some{Nothing}} = nothing,
    nucleotide_id::Union{MaybeInt, Some{Nothing}} = nothing,
    residue_id::Union{MaybeInt, Some{Nothing}} = nothing
) where T
    filter(row ->
        (isnothing(frame_id)      || row.frame_id == frame_id) &&
        (isnothing(molecule_id)   || row.molecule_id == something(molecule_id)) &&
        (isnothing(chain_id)      || row.chain_id == something(chain_id)) &&
        (isnothing(fragment_id)   || row.fragment_id == something(fragment_id)) &&
        (isnothing(nucleotide_id) || row.nucleotide_id == something(nucleotide_id)) &&
        (isnothing(residue_id)    || row.residue_id == something(residue_id)),
        substruct._atoms
    )
end

@inline function _bonds(substruct::Substructure; kwargs...)
    aidx = Set(_filter_select(_atoms(substruct; kwargs...), :idx))
    filter(row -> row.a1 in aidx || row.a2.idx, substruct._bonds)
end

@inline function _molecules(substruct::Substructure; kwargs...)
    midx = Set(_filter_select(_atoms(substruct; kwargs...), :molecule_id))
    filter(row -> row.idx in midx, molecules(substruct.parent))
end

@inline function _chains(substruct::Substructure; kwargs...)
    cidx = Set(_filter_select(_atoms(substruct; kwargs...), :chain_id))
    filter(row -> row.idx in cidx, chains(substruct.parent))
end

@inline function _fragments(substruct::Substructure; kwargs...)
    fidx = Set(_filter_select(_atoms(substruct; kwargs...), :fragment_id))
    filter(row -> row.idx in fidx, fragments(substruct.parent))
end

@inline function _nucleotides(substruct::Substructure; kwargs...)
    nidx = Set(_filter_select(_atoms(substruct; kwargs...), :nucleotide_id))
    filter(row -> row.idx in nidx, nucleotides(substruct.parent))
end

@inline function _residues(substruct::Substructure; kwargs...)
    ridx = Set(_filter_select(_atoms(substruct; kwargs...), :residue_id))
    @rsubset(
        _residues(substruct.parent), :idx in ridx; view = true
    )::SubDataFrame{DataFrame, DataFrames.Index, <:AbstractVector{Int}}
end

@inline function eachatom(substruct::Substructure{T}; kwargs...) where T
    (atom for atom in _atoms(substruct; kwargs...))
end

@inline function atoms(substruct::Substructure; kwargs...)
    _atoms(substruct; kwargs...)
end

@inline function eachbond(substruct::Substructure{T}; kwargs...) where T
    (bond for bond in _bonds(substruct; kwargs...))
end

@inline function bonds(substruct::Substructure; kwargs...)
    _bonds(substruct; kwargs...)
end

@inline function eachfragment(substruct::Substructure{T}; kwargs...) where T
    (frag for frag in _fragments(substruct; kwargs...))
end

@inline function fragments(substruct::Substructure{T}; kwargs...) where T
    _fragments(substruct; kwargs...)
end

@inline function eachchain(substruct::Substructure{T}; kwargs...) where T
    (chain for chain in _chains(substruct; kwargs...))
end

@inline function chains(substruct::Substructure{T}; kwargs...) where T
    _chains(substruct; kwargs...)
end

@inline function atoms_df(ac::Substructure{T}; kwargs...) where {T<:Real}
    DataFrame(_atoms(ac; kwargs...))
end

@inline function bonds_df(ac::Substructure{T}; kwargs...) where {T<:Real}
    DataFrame(_bonds(ac; kwargs...))
end

@inline function natoms(substruct::Substructure; kwargs...)
    length(_atoms(substruct; kwargs...))
end

@inline function nbonds(substruct::Substructure; kwargs...)
    length(_bonds(substruct; kwargs...))
end

@inline function nfragments(substruct::Substructure; kwargs...)
    length(_fragments(substruct; kwargs...))
end

@inline Base.parent(substruct::Substructure) = parent(substruct.parent)
@inline parent_system(substruct::Substructure) = parent_system(substruct.parent)

@inline function atom_by_idx(substruct::Substructure{T}, idx::Int) where T
    sys = substruct.parent isa System{T} ? substruct.parent : parent_system(substruct.parent)
    atom_by_idx(sys, idx)
end
