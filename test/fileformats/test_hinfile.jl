@testitem "reading HIN files" begin
    sys = load_hinfile(ball_data_path("../test/data/hinfile_test.hin"))

    @test natoms(sys) == 648
    @test nmolecules(sys) == 216
    @test nfragments(sys) == 0

    a = first(atoms(sys))
    @test a.name == "O"
    @test a.element == Elements.O
    @test a.charge ≈ -0.834
    @test a.r ≈ Vector3(0.59038, -0.410275, -0.860515)
    # TODO: handle radii
    # @test a.radius == 1.4
    @test nbonds(a) == 2

    @test get_property(sys, :temperature) ≈ 297.5626

    @test get_property(sys, :periodic_box_width)  ≈ 18.70136
    @test get_property(sys, :periodic_box_height) ≈ 18.70136
    @test get_property(sys, :periodic_box_depth)  ≈ 18.70136

    sys = load_hinfile(ball_data_path("../test/data/AlaGlySer.hin"))

    @test natoms(sys) == 31
    @test nmolecules(sys) == 1
    @test nfragments(sys) == 3
    @test nresidues(sys) == 3
    @test nchains(sys) == 1
    @test nbonds(sys) == 30

    @test_throws SystemError load_hinfile(ball_data_path("../test/data/ASDFASDFASEFADSFASDFAEW.hin"))
    @test_throws MethodError load_hinfile(ball_data_path("../test/data/hinfile_test_invalid.hin"))
end