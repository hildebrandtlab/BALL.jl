using StructTypes
using JSON3
using AutoHashEquals

import DataStructures: OrderedCollections.OrderedDict

export FragmentDB, get_reference_fragment

@auto_hash_equals struct DBNode
    key::String
    value::Union{AbstractArray{DBNode}, String}
end
StructTypes.StructType(::Type{DBNode}) = StructTypes.Struct()

@auto_hash_equals struct DBAtom{T<:Real}
    name::String
    element::ElementType
    r::Vector3{Angstrom{T}}

    function DBAtom{T}(name::String, element::ElementType, r::Union{Position{T}, Vector3{T}}) where {T<:Real}
        new(name, element, convert(Position{T}, r) .|> u"Å")
    end

    function DBAtom{T}(n::DBNode) where {T<:Real}
        name = n.key

        raw_data = split(n.value)

        if length(raw_data) == 4
            element = parse(Elements, raw_data[1])

            r = Position(map(d -> parse(T, d), raw_data[2:4]))

            return new(name, element, r)
        end

        throw(ArgumentError("DBAtom: invalid format!"))
    end
end
StructTypes.StructType(::Type{DBAtom{T}}) where {T<:Real} = StructTypes.Struct()

DBAtom(n::DBNode) = DBAtom{Float32}(n)

function find_atom(name, atoms::Vector{DBAtom{T}}) where {T<:Real}
    candidates = filter(a -> a.name == name, atoms)

    if length(candidates) != 1
        throw(ArgumentError("FragmentDB::find_atom: atom not found!"))
    end
    
    candidates[1]
end

function to_bond_order(s)
    order = BondOrder.Unknown

    if s == "s"
        order = BondOrder.Single
    elseif s == "d"
        order = BondOrder.Double
    elseif s == "t"
        order = BondOrder.Triple
    elseif s == "a"
        order = BondOrder.Aromatic
    else
        throw(ArgumentError("DBBond: invalid format!"))
    end

    order
end

@auto_hash_equals struct DBBond
    number::Int
    a1::String
    a2::String
    order::BondOrderType

    function DBBond(number::Int, a1::String, a2::String, order::BondOrderType)
        new(number, a1, a2, order)
    end

    function DBBond(n::DBNode)
        number = parse(Int, n.key)

        raw_data = split(n.value)

        a1 = raw_data[1]
        a2 = raw_data[2]
        
        order = to_bond_order(raw_data[3])

        new(number, a1, a2, order)
    end
end

@auto_hash_equals struct DBConnection{T<:Real}
    name::String
    atom_name::String
    match_name::String
    order::BondOrderType
    distance::Angstrom{T}
    tolerance::Angstrom{T}

    function DBConnection{T}(n::DBNode) where {T<:Real}
        name = n.key

        raw_data = split(n.value)

        if length(raw_data) != 5
            throw(ArgumentError("DBConnection: invalid format!"))
        end

        atom_name  = raw_data[1]
        match_name = raw_data[2]
        order      = to_bond_order(raw_data[3])

        distance   = Angstrom(parse(T, raw_data[4]))
        tolerance  = Angstrom(parse(T, raw_data[5]))

        new(name, atom_name, match_name, order, distance, tolerance)
    end
end

DBConnection(n::DBNode) = DBConnection{Float32}(n)

@auto_hash_equals struct DBProperty
    name::String
    value::Bool

    function DBProperty(n::DBNode)
        if startswith(n.key, "!")
            return new(n.key[2:end], false)
        else
            return new(n.key, true)
        end
    end
end

abstract type DBVariantAction end

@auto_hash_equals struct DBVariantDelete <: DBVariantAction
    atoms::Array{String}

    function DBVariantDelete(n::DBNode)
        new([a.key for a in n.value])
    end
end

@auto_hash_equals struct DBVariantRename <: DBVariantAction
    atoms::Dict{String, String}

    function DBVariantRename(n::DBNode)
        new(Dict(v.key => v.value for v in n.value))
    end
end

@auto_hash_equals struct DBVariant{T<:Real}
    name::String

    atoms::Array{DBAtom{T}}
    bonds::Array{DBBond}

    actions::Array{DBVariantAction}
    properties::Array{DBProperty}

    function DBVariant{T}(n::DBNode, atoms::Array{DBAtom{T}}, bonds::Array{DBBond}) where {T<:Real}
        name = n.key
        actions = []
        properties = []

        # variants can be of type delete or rename, and can carry properties
        for child in n.value
            if child.key == "Properties"
                properties = map(DBProperty, child.value)
            elseif child.key == "Delete"
                db_delete = DBVariantDelete(child)

                atoms = filter(a -> a.name ∉ db_delete.atoms, atoms)
                bonds = filter(b -> b.a1 ∉ db_delete.atoms && b.a2 ∉ db_delete.atoms, bonds)
                
                push!(actions, db_delete)
            elseif child.key == "Rename"
                db_rename = DBVariantRename(child)

                atoms = map(
                    a -> DBAtom{T}(get(db_rename.atoms, a.name, a.name), a.element, a.r), atoms)
                bonds = map(
                    b -> DBBond(b.number,
                            get(db_rename.atoms, b.a1, b.a1),
                            get(db_rename.atoms, b.a2, b.a2),
                            b.order), bonds)
                                
                push!(actions, db_rename)
            else
                throw(ArgumentError("DBVariant: invalid format!"))
            end
        end

        new(name, atoms, bonds, actions, properties)
    end
end

function bonds(a::DBAtom, var::DBVariant)
    filter(b -> a.name ∈ [b.a1, b.a2], var.bonds)
end

function get_partner(bond::DBBond, atom::DBAtom, var::DBVariant)
    if bond.a1 == atom.name
        return var.atoms[findfirst(a -> a.name == bond.a2, var.atoms)]
    elseif bond.a2 == atom.name
        return var.atoms[findfirst(a -> a.name == bond.a1, var.atoms)]
    else
        return nothing
    end
end

@auto_hash_equals struct DBFragment{T<:Real}
    name::String
    path::String

    names::Array{String}
    atoms::Array{DBAtom{T}}
    bonds::Array{DBBond}
    connections::Array{DBConnection{T}}
    properties::Array{DBProperty}
    variants::Array{DBVariant{T}}
    
    function DBFragment{T}(n::DBNode) where {T<:Real}
        if startswith(n.key, "#include:")
            name = split(n.key, ":")[2]
            path = ball_data_path(split(n.value, ":")[1] * ".json")

            raw_fragment_data = JSON3.read(read(path, String), Array{DBNode})

            raw_names = filter(n -> n.key == "Names", raw_fragment_data)
            names = length(raw_names) == 1 ? [n.key for n in raw_names[1].value] : []
            
            raw_atoms = filter(n -> n.key == "Atoms", raw_fragment_data)
            atoms = length(raw_atoms) == 1 ? map(DBAtom{T}, raw_atoms[1].value) : []

            raw_bonds = filter(n -> n.key == "Bonds", raw_fragment_data)
            bonds = length(raw_bonds) == 1 ? map(b -> DBBond(b), raw_bonds[1].value) : []

            raw_connections = filter(n -> n.key == "Connections", raw_fragment_data)
            connections = length(raw_connections) == 1 ? map(c -> DBConnection{T}(c), raw_connections[1].value) : []
            
            raw_properties = filter(n -> n.key == "Properties", raw_fragment_data)
            properties = length(raw_properties) == 1 ? map(DBProperty, raw_properties[1].value) : []

            raw_variants = filter(n -> n.key == "Variants", raw_fragment_data)
            variants = length(raw_variants) == 1 ? map(v-> DBVariant{T}(v, atoms, bonds), raw_variants[1].value) : []
            
            return new(name, path, names, atoms, bonds, connections, properties, variants)
        end

        throw(ArgumentError("DBFragment: invalid format!"))
    end
end
StructTypes.StructType(::Type{DBFragment}) = StructTypes.CustomStruct()

DBFragment(n::DBNode) = DBFragment{Float32}(n)

@auto_hash_equals struct DBNameMapping
    name::String
    maps_to::String

    mappings::Dict{String, String}

    function DBNameMapping(n::DBNode)
        if !startswith(n.key, "#include:")
            throw(ArgumentError("DBNameMapping: invalid format!"))
        end
    
        name = split(n.key, ":")[2]
        path = ball_data_path(split(n.value, ":")[1] * ".json")

        raw_mapping_data = JSON3.read(read(path, String), Array{DBNode})

        # the first node in the value list contains the reference
        if length(raw_mapping_data) == 0
            throw(ArgumentError("DBNameMapping: invalid format!"))
        end

        maps_to = raw_mapping_data[1].key

        mappings = Dict{String, String}(
            n.key => n.value for n in raw_mapping_data[2:end]
        )

        new(name, maps_to, mappings)
    end
end

@auto_hash_equals struct FragmentDB{T<:Real}
    fragments::OrderedDict{String, DBFragment{T}}
    name_mappings::OrderedDict{String, DBNameMapping}
    defaults::OrderedDict{String, String}

    function FragmentDB{T}(nodes::Vector{DBNode}) where {T<:Real}
        if length(nodes) == 3
            raw_fragments = filter(n -> n.key == "Fragments", nodes)
            raw_names     = filter(n -> n.key == "Names",     nodes)
            raw_defaults  = filter(n -> n.key == "Defaults",  nodes)

            if length(raw_fragments) == length(raw_names) == length(raw_defaults) == 1
                fragments = OrderedDict{String, DBFragment{T}}(
                    f.name => f for f in map(DBFragment{T}, raw_fragments[1].value)
                )
                
                name_mappings = OrderedDict{String, DBNameMapping}(
                    nm.name => nm for nm in map(DBNameMapping, raw_names[1].value)
                )

                defaults = OrderedDict{String, String}(
                    d.key => d.value for d in raw_defaults[1].value
                )

                return new(fragments, name_mappings, defaults)
            end
        end
        
        throw(ArgumentError("FragmentDB: invalid format!"))
    end

    function FragmentDB{T}(path::String = ball_data_path("fragments/Fragments.db.json")) where {T<:Real}
        jstring = read(path, String)
        
        JSON3.read(jstring, FragmentDB{T})
    end
end
StructTypes.StructType(::Type{FragmentDB{T}}) where {T} = StructTypes.CustomStruct()
StructTypes.lowertype(::Type{FragmentDB{T}}) where {T} = Array{DBNode}

FragmentDB(path::String = ball_data_path("fragments/Fragments.db.json")) = FragmentDB{Float32}(path)

function label_terminal_fragments!(ac::AbstractAtomContainer{T}) where {T<:Real}
    # iterate over all chains and label their terminals
    for chain in eachchain(ac)
        if nfragments(chain) > 0
            # first, the n- and c-terminals
            amino_acids = filter(is_amino_acid, fragments(chain))

            if length(amino_acids) > 0
                set_flag!(first(amino_acids), :N_TERMINAL)
                set_flag!(last(amino_acids),  :C_TERMINAL)
            end

            # then, the 3-, and 5-primes
            nucleotides = filter(is_nucleotide, fragments(chain))

            if length(nucleotides) > 0
                set_flag!(first(nucleotides), Symbol("3_PRIME"))
                set_flag!(last(nucleotides),  Symbol("5_PRIME"))
            end

        end
    end
end

function get_reference_fragment(f::Fragment{T}, fdb::FragmentDB) where {T<:Real}
    # first, try to find the fragment in the database
    if f.name ∉ keys(fdb.fragments)
        return nothing
    end

    db_fragment = fdb.fragments[f.name]

    # does the fragment have variants?
    if length(db_fragment.variants) == 1
        return db_fragment.variants[1]
    end

    # now, find the variant that best matches the fragment
    # This returns N/C terminal variants for fragments that
    # have the corresponding properties set or cystein variants
    # without thiol hydrogen if the disulphide bond property
    # is set

    # the number of properties that matched
    # the fragment with the largest number of matched
    # properties is returned
    number_of_properties = -1
    property_difference = -1
    best_number_of_properties = -1
    best_property_difference = 10000

    best_variant = nothing

    # DBFragments don't know anything about flags, they only know properties
    # so we mix them together here
    f_props = merge(f.properties, Dict{Symbol, Any}(flag => true for flag in f.flags))
    is_true(x) = typeof(x) === Bool && x

    # iterate over all variants of the fragment and compare the properties
    for var in db_fragment.variants
        var_props = Dict(Symbol(p.name) => p.value for p in var.properties)

        # count the difference in the number of set properties
        property_difference = abs(length(findall(is_true, f_props)) - length(findall(is_true, var_props)))

        # and count the properties fragment and variant have in common
        number_of_properties = length(f_props ∩ var_props)

        @debug "Considering variant $(var.name). # properties: $(number_of_properties)"

        if ((number_of_properties > best_number_of_properties)
            || (   (number_of_properties == best_number_of_properties)
                && (property_difference < best_property_difference)))
            best_variant = var
            best_number_of_properties = number_of_properties
            best_property_difference  = property_difference
        end
    end

    best_variant
end

Base.show(io::IO, fdb::FragmentDB) = 
    print(io, 
        "FragmentDB with $(length(fdb.fragments)) fragments, " *
        "$(length(fdb.name_mappings)) mappings, $(length(fdb.defaults)) defaults.")