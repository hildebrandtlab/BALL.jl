@testitem "Atom" begin
    for T in [Float32, Float64]
        at = BiochemicalAlgorithms._Atom{T}(1, Elements.H;
            name = "my fancy atom",
            atom_type = "heavy",
            r = Vector3{T}(1, 2, 4),
            v = Vector3{T}(1, 1, 1),
            formal_charge = 1,
            charge = T(0.2),
            radius = T(1.01)
        )
        sys = System{T}()

        # constructors + parent
        atom = Atom(sys, at.number, at.element;
            name = at.name,
            atom_type = at.atom_type,
            r = at.r,
            v = at.v,
            formal_charge = at.formal_charge,
            charge = at.charge,
            radius = at.radius
        )
        @test atom isa Atom{T}
        @test parent(atom) === sys
        @test parent_system(atom) === sys
        T == Float32 && @test parent(Atom(at.number, at.element)) === default_system()
        T == Float32 && @test parent_system(Atom(at.number, at.element)) === default_system()

        atom2 = Atom(sys, at.number, at.element;
            name = at.name,
            atom_type = at.atom_type,
            r = at.r,
            v = at.v,
            formal_charge = at.formal_charge,
            charge = at.charge,
            radius = at.radius,
            frame_id = 10,
            molecule_idx = 11,
            chain_idx = 12,
            fragment_idx = 13,
            nucleotide_idx = 14,
            residue_idx = 15
        )

        #=
            Make sure we test for the correct number of fields.
            Add missing tests if the following test fails!
        =#
        @test length(getfield(atom, :_row)) == 13

        # getproperty
        @test atom.idx isa Int
        @test atom.number isa Int
        @test atom.number == at.number
        @test atom.element isa ElementType
        @test atom.element == at.element
        @test atom.name isa String
        @test atom.name == at.name
        @test atom.atom_type isa String
        @test atom.atom_type == at.atom_type
        @test atom.r isa Vector3{T}
        @test atom.r == at.r
        @test atom.v isa Vector3{T}
        @test atom.v == at.v
        @test atom.F isa Vector3{T}
        @test atom.F == at.F
        @test atom.formal_charge isa Int
        @test atom.formal_charge == at.formal_charge
        @test atom.charge isa T
        @test atom.charge == at.charge
        @test atom.radius isa T
        @test atom.radius == at.radius
        @test atom.properties isa Properties
        @test atom.properties == at.properties
        @test atom.flags isa Flags
        @test atom.flags == at.flags

        @test atom._sys isa System{T}
        @test atom._row isa BiochemicalAlgorithms._AtomTableRow{T}

        @test atom.frame_id isa Int
        @test atom.frame_id == 1
        @test isnothing(atom.molecule_idx)
        @test isnothing(atom.chain_idx)
        @test isnothing(atom.fragment_idx)
        @test isnothing(atom.nucleotide_idx)
        @test isnothing(atom.residue_idx)

        @test atom2.frame_id isa Int
        @test atom2.frame_id == 10
        @test atom2.molecule_idx isa Int
        @test atom2.molecule_idx == 11
        @test atom2.chain_idx isa Int
        @test atom2.chain_idx == 12
        @test atom2.fragment_idx isa Int
        @test atom2.fragment_idx == 13
        @test atom2.nucleotide_idx isa Int
        @test atom2.nucleotide_idx == 14
        @test atom2.residue_idx isa Int
        @test atom2.residue_idx == 15

        # setproperty!
        atom.number = 42
        @test atom.number == 42
        atom.element = Elements.C
        @test atom.element == Elements.C
        atom.name = "another name"
        @test atom.name == "another name"
        atom.atom_type = "none"
        @test atom.atom_type == "none"
        atom.r = Vector3{T}(10, 20, 30)
        @test atom.r == Vector3{T}(10, 20, 30)
        atom.v = Vector3{T}(100, 200, 300)
        @test atom.v == Vector3{T}(100, 200, 300)
        atom.F = Vector3{T}(1000, 2000, 3000)
        @test atom.F == Vector3{T}(1000, 2000, 3000)
        atom.formal_charge = 2
        @test atom.formal_charge == 2
        atom.charge = -one(T)
        @test atom.charge == -one(T)
        atom.radius = one(T) / 2
        @test atom.radius == one(T) / 2
        atom.properties = Properties(:first => "v1", :second => 99)
        @test length(atom.properties) == 2
        @test atom.properties[:first] == "v1"
        @test atom.properties[:second] == 99
        atom.flags = Flags([:A, :B])
        @test length(atom.flags) == 2
        @test :A in atom.flags
        @test :B in atom.flags

        atom3 = Atom(System{T}(), at.number, at.element; name = at.name, frame_id = 10)
        atom3.frame_id = 999
        @test atom3.frame_id == 999
        atom3.molecule_idx = 998
        @test atom3.molecule_idx == 998
        atom3.chain_idx = 997
        @test atom3.chain_idx == 997
        atom3.fragment_idx = 996
        @test atom3.fragment_idx == 996
        atom3.nucleotide_idx = 995
        @test atom3.nucleotide_idx == 995
        atom3.residue_idx = 994
        @test atom3.residue_idx == 994

        # atom_by_idx
        @test_throws KeyError atom_by_idx(sys, -1)
        @test atom_by_idx(sys, atom.idx) isa Atom{T}
        @test atom_by_idx(sys, atom.idx) == atom

        # atom_by_name
        @test isnothing(atom_by_name(sys, "invalid"))
        @test atom_by_name(sys, atom.name) isa Atom{T}
        @test atom_by_name(sys, atom.name) == atom
        @test atom_by_name(sys, atom.name; frame_id = 1) == atom
        @test isnothing(atom_by_name(sys, atom.name; frame_id = 9999))
        @test isnothing(atom_by_name(sys, atom2.name))
        @test atom_by_name(sys, atom2.name; frame_id = 10) == atom2
        mol = Molecule(sys)
        atom3 = Atom(mol, at.number, at.element; name = at.name, frame_id = 10)
        @test atom_by_name(mol, atom3.name; frame_id = 10) == atom3

        # atoms
        avec = atoms(sys)
        @test avec isa AtomTable{T}
        @test length(avec) == 1
        @test length(atoms(sys, frame_id = 1)) == 1
        @test length(atoms(sys, frame_id = 2)) == 0
        @test length(atoms(sys, frame_id = 10)) == 2
        @test length(atoms(sys, frame_id = nothing)) == 3
        @test length(atoms(sys, frame_id = nothing, molecule_idx =11, chain_idx = 12, fragment_idx = 13,
            nucleotide_idx = 14, residue_idx = 15)) == 1

        # natoms + push!
        @test natoms(sys) isa Int
        @test natoms(sys) == 1
        @test natoms(sys, frame_id = 1) == 1
        @test natoms(sys, frame_id = 2) == 0
        @test natoms(sys, frame_id = 10) == 2
        @test natoms(sys, frame_id = nothing) == 3
        @test natoms(sys, frame_id = nothing, molecule_idx =11, chain_idx = 12, fragment_idx = 13,
            nucleotide_idx = 14, residue_idx = 15) == 1

        @test push!(sys, atom) === sys
        @test natoms(sys) == 2
        @test push!(sys, atom, frame_id = 100, molecule_idx = 101, chain_idx = 102, fragment_idx = 103, 
            nucleotide_idx = 104, residue_idx = 105) === sys
        @test natoms(sys) == 2
        @test natoms(sys, frame_id = 100) == 1

        # test is_geminal, is_vicinal
        a = Atom(sys, at.number, at.element)
        b = Atom(sys, at.number, at.element)
        c = Atom(sys, at.number, at.element)

        @test !is_geminal(a, a)
        @test !is_geminal(a, b)

        Bond(sys, a.idx, b.idx, BondOrder.Single)
        Bond(sys, b.idx, c.idx, BondOrder.Single)
        
        @test !is_geminal(a, b)
        @test is_geminal(a, c)
        @test is_geminal(c, a)

        a = Atom(sys, at.number, at.element)
        b = Atom(sys, at.number, at.element)
        c = Atom(sys, at.number, at.element)
        d = Atom(sys, at.number, at.element)

        @test !is_vicinal(a, a)
        @test !is_vicinal(a, b)

        Bond(sys, a.idx, b.idx, BondOrder.Single)
        Bond(sys, b.idx, c.idx, BondOrder.Single)
        Bond(sys, c.idx, d.idx, BondOrder.Single)

        @test !is_vicinal(a, a)
        @test !is_vicinal(a, c)
        @test is_vicinal(a, d)
        @test is_vicinal(d, a)

        # atom bonds
        @test length(bonds(atom)) == 0
        @test nbonds(atom) == 0

        @test parent(Bond(
            sys,
            atom.idx,
            Atom(sys, 2, Elements.C).idx,
            BondOrder.Single
        )) === sys
        @test length(bonds(atom)) == 1
        @test nbonds(atom) == 1

        @test parent(Bond(
            sys,
            Atom(sys, 3, Elements.C).idx,
            atom.idx,
            BondOrder.Double
        )) === sys
        @test length(bonds(atom)) == 2
        @test nbonds(atom) == 2

        @test parent(Bond(
            sys,
            Atom(sys, 4, Elements.C).idx,
            Atom(sys, 5, Elements.C).idx,
            BondOrder.Double
        )) === sys
        @test length(bonds(atom)) == 2
        @test nbonds(atom) == 2
    end
end
