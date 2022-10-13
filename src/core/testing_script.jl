using BiochemicalAlgorithms

export load_all, run_atomtyping, string_as_variable_name, conti_return, testing_loop_conti

function load_all()
    file_location_a = "test/data/gaff_paper_examples/a/"
    file_location_b = "test/data/gaff_paper_examples/b/"
    row_count_a = lastindex(readdir(file_location_a))
    row_count_total = lastindex(readdir(file_location_a)) + lastindex(readdir(file_location_b))
    mol_df = DataFrame([Vector{String}(undef, row_count_total), Vector{AbstractMolecule}(undef, row_count_total)], ["molname", "abstract_mol"])
    for (num, i) in enumerate(readdir(file_location_a))
        mol_df.molname[num] = string("mol_a_", i[1:2])
        mol_df.abstract_mol[num] = load_pubchem_json(string(file_location_a, i))
    end
    for (num, i) in enumerate(readdir(file_location_b))
        num_b = num + row_count_a
        mol_df.molname[num_b] = string("mol_b_", i[1:2])
        mol_df.abstract_mol[num_b] = load_pubchem_json(string(file_location_b, i))
    end
    return mol_df
end

function run_atomtyping()
    mol_df = load_all()
    df = select_atomtyping()
    exit_dict = Dict{Symbol, DataFrame}
    # println((nrow(mol_df))
    for num = (1:nrow(mol_df))
        # println((num, "/", nrow(mol_df),", name: ",string(mol_df.molname[num]))
        atomtypes_list = get_atomtype(mol_df.abstract_mol[num], df)
        exit_dict = merge(exit_dict, Dict(Symbol(string(mol_df.molname[num],"atomtypes")) => atomtypes_list))
    end
    return exit_dict
end


function gaff_paper_test(mol_dict::AbstractDict)
    a_dict = Dict{String, Vector{String}}
end


function string_as_variable_name(str::AbstractString, var::Any)
    str = Symbol(str)
    return @eval (($str) = ($var))
end
