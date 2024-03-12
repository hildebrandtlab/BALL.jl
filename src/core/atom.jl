export
    Atom,
    AtomTable,
    atom_by_idx,
    atom_by_name,
    atoms,
    natoms,
    has_property,
    get_property,
    set_property,
    get_full_name,
    is_bound_to,
    is_geminal,
    is_vicinal

@auto_hash_equals struct AtomTable{T} <: Tables.AbstractColumns
    _sys::System{T}
    _idx::Vector{Int}
end

@inline _atoms(at::AtomTable) = getproperty(getfield(at, :_sys), :_atoms)

@inline Tables.istable(::Type{<: AtomTable}) = true
@inline Tables.columnaccess(::Type{<: AtomTable}) = true
@inline Tables.columns(at::AtomTable) = at
@inline Tables.rows(at::AtomTable) = at

@inline function Tables.getcolumn(at::AtomTable, nm::Symbol)
    col = Tables.getcolumn(_atoms(at), nm)
    RowProjectionVector{eltype(col)}(
        col,
        map(idx -> _atoms(at)._idx_map[idx], getfield(at, :_idx))
    )
end

@inline Tables.getcolumn(at::AtomTable, i::Int) = Tables.getcolumn(at, Tables.columnnames(at)[i])
@inline Tables.columnnames(at::AtomTable) = Tables.columnnames(_atoms(at))
@inline Tables.schema(at::AtomTable) = Tables.schema(_atoms(at))

@inline Base.size(at::AtomTable) = (length(getfield(at, :_idx)), length(_atom_table_cols))
@inline Base.size(at::AtomTable, dim) = size(at)[dim]
@inline Base.length(at::AtomTable) = size(at, 1)

@inline function Base.getproperty(at::AtomTable, nm::Symbol)
    hasfield(typeof(at), nm) && return getfield(at, nm)
    Tables.getcolumn(at, nm)
end

@inline function Base.setproperty!(at::AtomTable, nm::Symbol, val)
    if nm in _atom_table_cols_priv || nm in _atom_table_cols_set
        error("AtomTable columns cannot be set directly! Did you mean to use broadcast assignment (.=)?")
    end
    if !hasfield(typeof(at), nm)
        error("type AtomTable has no field $nm")
    end
    setfield!(at, nm, val)
end

@inline function _filter_atoms(f::Function, sys::System{T}) where T
    AtomTable(sys, collect(Int, _filter_select(
        TableOperations.filter(f, sys._atoms),
        :idx
    )))
end

@inline function Base.filter(f::Function, at::AtomTable)
    AtomTable(getfield(at, :_sys), collect(Int, _filter_select(
        TableOperations.filter(f, at),
        :idx
    )))
end

@inline function Base.iterate(at::AtomTable, st = 1)
    st > length(at) ?
        nothing :
        (atom_by_idx(getfield(at, :_sys), getfield(at, :_idx)[st]), st + 1)
end
@inline Base.eltype(::AtomTable{T}) where T = Atom{T}
@inline Base.getindex(at::AtomTable{T}, i::Int) where T = atom_by_idx(getfield(at, :_sys), getfield(at, :_idx)[i])
@inline Base.keys(at::AtomTable) = LinearIndices((length(at),))

"""
    $(TYPEDEF)

Mutable representation of an individual atom in a system.

# Fields
 - `idx::Int`
 - `number::Int`
 - `element::ElementType`
 - `name::String`
 - `atom_type::String`
 - `r::Vector3{T}`
 - `v::Vector3{T}`
 - `F::Vector3{T}`
 - `formal_charge::Int`
 - `charge::T`
 - `radius::T`
 - `properties::Properties`
 - `flags::Flags`

# Constructors
```julia
Atom(
    number::Int,
    element::ElementType,
    name::String = "",
    atom_type::String = "",
    r::Vector3{T} = Vector3{T}(0, 0, 0),
    v::Vector3{T} = Vector3{T}(0, 0, 0),
    F::Vector3{T} = Vector3{T}(0, 0, 0),
    formal_charge::Int = 0,
    charge::T = zero(T),
    radius::T = zero(T),
    properties::Properties = Properties(),
    flags::Flags = Flags();
    # keyword arguments
    frame_id::Int = 1
)
```
Creates a new `Atom{Float32}` in the default system.
"""
@auto_hash_equals struct Atom{T} <: AbstractSystemComponent{T}
    _sys::System{T}
    _row::_AtomTableRow{T}
end

@inline function Atom(
    sys::System{T},
    number::Int,
    element::ElementType;
    frame_id::Int = 1,
    molecule_idx::MaybeInt = nothing,
    chain_idx::MaybeInt = nothing,
    fragment_idx::MaybeInt = nothing,
    nucleotide_idx::MaybeInt = nothing,
    residue_idx::MaybeInt = nothing,
    kwargs...
) where T
    idx = _next_idx(sys)
    push!(sys._atoms, _Atom{T}(number, element; idx = idx, kwargs...);
        frame_id = frame_id,
        molecule_idx = molecule_idx,
        chain_idx = chain_idx,
        fragment_idx = fragment_idx,
        nucleotide_idx = nucleotide_idx,
        residue_idx = residue_idx
    )
    atom_by_idx(sys, idx)
end

@inline function Atom(
    number::Int,
    element::ElementType;
    kwargs...
)
    Atom(default_system(), number, element; kwargs...)
end

@inline function Base.getproperty(atom::Atom, name::Symbol)
    hasfield(typeof(atom), name) && return getfield(atom, name)
    getproperty(getfield(atom, :_row), name)
end

@inline function Base.setproperty!(atom::Atom, name::Symbol, val)
    hasfield(typeof(atom), name) && return setfield!(atom, name, val)
    setproperty!(getfield(atom, :_row), name, val)
end

@inline Base.show(io::IO, ::MIME"text/plain", atom::Atom) = show(io, getfield(atom, :_row))
@inline Base.show(io::IO, atom::Atom) = show(io, getfield(atom, :_row))

@inline Base.parent(atom::Atom) = atom._sys
@inline parent_system(atom::Atom) = parent(atom)

@inline function parent_molecule(atom::Atom) 
    isnothing(atom.molecule_idx) ?
        nothing :
        molecule_by_idx(parent(atom), atom.molecule_idx)
end

@inline function parent_chain(atom::Atom)
    isnothing(atom.chain_idx) ?
        nothing :
        chain_by_idx(atom._sys, atom.chain_idx)
end

@inline function parent_fragment(atom::Atom)
    isnothing(atom.fragment_idx) ?
        nothing :
        fragment_by_idx(parent(atom), atom.fragment_idx)
end

@inline function parent_nucleotide(atom::Atom)
    isnothing(atom.nucleotide_idx) ?
        nothing :
        nucleotide_by_idx(parent(atom), atom.nucleotide_idx)
end

@inline function parent_residue(atom::Atom)
    isnothing(atom.residue_idx) ?
        nothing :
        residue_by_idx(parent(atom), atom.residue_idx)
end

"""
    $(TYPEDSIGNATURES)

Returns the `Atom{T}` associated with the given `idx` in `sys`. Throws a `KeyError` if no such
atom exists.
"""
@inline function atom_by_idx(sys::System{T}, idx::Int) where T
    Atom{T}(sys, _row_by_idx(sys._atoms, idx))
end

"""
    $(TYPEDSIGNATURES)

Returns the first `Atom{T}` associated with the given `name` in `ac`. Returns nothing if no such
atom exists.

# Supported keyword arguments
 - `frame_id::MaybeInt = 1`: \
Any value other than `nothing` limits the result to atoms matching this frame ID.
"""
@inline function atom_by_name(
    ac::AbstractAtomContainer{T},
    name::String;
    frame_id::MaybeInt = 1
) where T
    idx = filter(atom -> atom.name == name, atoms(ac; frame_id = frame_id)).idx
    isempty(idx) ? nothing : atom_by_idx(parent(ac), first(idx))
end

"""
    atoms(::Chain)
    atoms(::Fragment)
    atoms(::Molecule)
    atoms(::Nucleotide)
    atoms(::Residue)
    atoms(::System)

Returns an `AtomTable{T}` containing all atoms of the given atom container.

# Supported keyword arguments
 - `frame_id::MaybeInt = 1`: \
Any value other than `nothing` limits the result to atoms matching this frame ID.
 - `molecule_idx::Union{MaybeInt, Some{Nothing}} = nothing`: \
Any value other than `nothing` limits the results to atoms belonging to the given molecule ID.
 - `chain_idx::Union{MaybeInt, Some{Nothing}} = nothing`: \
Any value other than `nothing` limits the results to atoms belonging to the given chain ID.
- `fragment_idx::Union{MaybeInt, Some{Nothing}} = nothing`: \
Any value other than `nothing` limits the results to atoms belonging to the given fragment ID.
- `nucleotide_idx::Union{MaybeInt, Some{Nothing}} = nothing`: \
Any value other than `nothing` limits the results to atoms belonging to the given nucleotide ID.
- `residue_idx::Union{MaybeInt, Some{Nothing}} = nothing`: \
Any value other than `nothing` limits the results to atoms belonging to the given residue ID.
"""
@inline function atoms(sys::System{T};
    frame_id::MaybeInt = 1,
    molecule_idx::Union{MaybeInt, Some{Nothing}} = nothing,
    chain_idx::Union{MaybeInt, Some{Nothing}} = nothing,
    fragment_idx::Union{MaybeInt, Some{Nothing}} = nothing,
    nucleotide_idx::Union{MaybeInt, Some{Nothing}} = nothing,
    residue_idx::Union{MaybeInt, Some{Nothing}} = nothing
) where T
    _filter_atoms(atom ->
        (isnothing(frame_id)       || atom.frame_id == frame_id) &&
        (isnothing(molecule_idx)   || atom.molecule_idx == something(molecule_idx)) &&
        (isnothing(chain_idx)      || atom.chain_idx == something(chain_idx)) &&
        (isnothing(fragment_idx)   || atom.fragment_idx == something(fragment_idx)) &&
        (isnothing(nucleotide_idx) || atom.nucleotide_idx == something(nucleotide_idx)) &&
        (isnothing(residue_idx)    || atom.residue_idx == something(residue_idx)),
        sys
    )
end

"""
    natoms(::Chain)
    natoms(::Fragment)
    natoms(::Molecule)
    natoms(::Nucleotide)
    natoms(::Residue)
    natoms(::System)

Returns the number of atoms in the given atom container.

# Supported keyword arguments
 - `frame_id::MaybeInt = 1`: \
Any value other than `nothing` limits the result to atoms matching this frame ID.
"""
@inline function natoms(sys::System; kwargs...)
    length(atoms(sys; kwargs...))
end

"""
    bonds(::Atom)

Returns a `BondTable{T}` containing all bonds of the given atom.
"""
@inline function bonds(atom::Atom)
    _filter_bonds(
        bond -> bond.a1 == atom.idx || bond.a2 == atom.idx,
        parent(atom)
    )
end

"""
    nbonds(::Atom)

Returns the number of bonds of the given atom.
"""
@inline function nbonds(atom::Atom)
    length(bonds(atom))
end

"""
    push!(::Fragment{T}, atom::Atom{T})
    push!(::Molecule{T}, atom::Atom{T})
    push!(::Nucleotide{T}, atom::Atom{T})
    push!(::Residue{T}, atom::Atom{T})
    push!(::System{T}, atom::Atom{T})

Creates a copy of the given atom in the given atom container. The new atom is automatically
assigned a new `idx`.

# Supported keyword arguments
 - `frame_id::Int = 1`
"""
@inline function Base.push!(sys::System{T}, atom::Atom{T};
    frame_id::Int = 1,
    molecule_idx::MaybeInt = nothing,
    chain_idx::MaybeInt = nothing,
    fragment_idx::MaybeInt = nothing,
    nucleotide_idx::MaybeInt = nothing,
    residue_idx::MaybeInt = nothing
) where T
    Atom(sys, atom.number, atom.element;
        name = atom.name,
        atom_type = atom.atom_type,
        r = atom.r,
        v = atom.v,
        F = atom.F,
        formal_charge = atom.formal_charge,
        charge = atom.charge,
        radius = atom.radius,
        properties = atom.properties,
        flags = atom.flags,
        frame_id = frame_id,
        molecule_idx = molecule_idx,
        chain_idx = chain_idx,
        fragment_idx = fragment_idx,
        nucleotide_idx = nucleotide_idx,
        residue_idx = residue_idx
    )
    sys
end

@enumx FullNameType begin
    # Do not add extensions
    NO_VARIANT_EXTENSIONS = 1
    # Add the residue extensions
    ADD_VARIANT_EXTENSIONS = 2
    # Add the residue ID
    ADD_RESIDUE_ID = 3
    # Add the residue ID and the residue extension
    ADD_VARIANT_EXTENSIONS_AND_ID = 4
end

function get_full_name(
    a::Atom{T},
    type::FullNameType.T = FullNameType.ADD_VARIANT_EXTENSIONS
) where {T<:Real}

    # determine the parent's name
    f = parent_fragment(a)

    parent_name = ""

    if isnothing(f)
        # look for a molecule containing the atom
        m = parent_molecule(a)
        parent_name = strip(m.name)
    else
        # retrieve the fragment name
        parent_name = get_full_name(f, type)
    end

    # retrieve the atom name
    name = strip(a.name)

    # add the parent name only if non-empty
    if !isempty(parent_name)
        name = string(parent_name, ":", name)
    end

    name
end

@inline distance(a1::Atom, a2::Atom) = distance(a1.r, a2.r)

"""
    $(TYPEDSIGNATURES)

    Decides if two atoms are bound to each other.
    Hydrogen bonds (has_flag(bond, :TYPE__HYDROGEN)) are ignored.
"""
function is_bound_to(a1::Atom, a2::Atom)
    s = parent(a1)

    if s != parent(a2)
        return false
    end

    return !isnothing(
        findfirst(
            b::Bond -> 
                ((b.a1 == a1.idx) && (b.a2 == a2.idx)) ||
                ((b.a1 == a2.idx) && (b.a2 == a1.idx)), 
            non_hydrogen_bonds(s)
        )
    )
end

"""
    $(TYPEDSIGNATURES)

    Decides if two atoms are geminal.
    
    Two atoms are geminal if they do not share a common bond but both have a
    bond to a third atom. For example the two hydrogen atoms in water are geminal. 
    Hydrogen bonds (has_flag(bond, :TYPE__HYDROGEN)) are ignored.
"""
function is_geminal(a1::Atom, a2::Atom)
    if a1 == a2
        return false
    end

    # an atom is geminal to another, if it is not directly bonded to it...
    is_geminal = !is_bound_to(a1, a2)

    # ...and is bonded to an atom that is bonded to the other atom
    is_geminal && any(map(b -> is_bound_to(get_partner(b, a1), a2), non_hydrogen_bonds(a1)))
end

"""
    $(TYPEDSIGNATURES)

Decides if two atoms are vicinal.

Two atoms are vicinal if they are separated by three bonds (1-4 position).
Hydrogen bonds (has_flag(bond, :TYPE__HYDROGEN)) are ignored.
"""
function is_vicinal(a1::Atom, a2::Atom)
    if a1 == a2
        return false
    end

    # an atom is vicinal to another, if it is not directly bonded to it...
    is_vicinal = !is_bound_to(a1, a2)

    # ...and is bonded to an atom that is bonded to an atom that is bonded to this atom
    if is_vicinal
        is_vicinal = false

        for b_1 in non_hydrogen_bonds(a1)
            partner_1 = get_partner(b_1, a1)

            for b_2 in non_hydrogen_bonds(partner_1)
                partner_2 = get_partner(b_2, partner_1)

                if is_bound_to(partner_2, a2)
                    return true
                end
            end
        end
    end

    return false
end
