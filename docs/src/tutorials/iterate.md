# All on iteration


When working with molecular entities, we want to run over all atoms of a
system, over all chains, … in this tutorial we will learn how this can
be done.

``` julia
using BiochemicalAlgorithms
```

:::{cell .markdown} \# Molecular systems In `BiochemicalAlgorithms.jl`
atoms and bonds are existing inside a `System`. Typically, molecular
data is stored in molecular data formats such as PDB. The latter can be
directly read into a system.

``` julia
s = load_pdb(ball_data_path("../test/data/AlaAla.pdb"))
natoms(s)
```

# How can I iterate over all atoms of a system?

We can easily iterate over *all atoms* of this *system*.

``` julia
for a in atoms(s)
    print(a.name)
end
```

``` julia
# we can actually write
print.(a.name for a in atoms(s))
```

# How can I iterate over specific atoms?

In many scenarios, we only want to iterate over a subset of atoms
fulfilling a specific criteria. For example, we only want to get the
positions of the $C\alpha$-atoms or we only want the heavy atoms: :::

``` julia
println.(a.r for a in atoms(s) if a.name == "CA")
```

``` julia
heavy_atoms = filter(atom -> atom.element != Elements.H, atoms(s))
# natoms(s)
length(heavy_atoms)
heavy_atoms
```

The filtering process gives us an `AtomTable`:

``` julia
typeof(s)
typeof(atoms(s))
typeof(heavy_atoms)
```

# How can I iterate over all atoms of a molecule?

Sometimes it is preferably to iterate over a molecule (e.g., in docking
scenarios where you only want to iterate over receptor atoms).

``` julia
# generate a molecule
mol = load_pdb(ball_data_path("../test/data/AlaAla.pdb"))
println.(a.name for a in atoms(mol))
```

# How can I iterate over all atoms of a residue?

``` julia
residue = residue_by_idx(s,1)
println.(a.element for a in atoms(res) )
```

# How can I iterate over all bonds of a system?

Bonds are not explicitely stored in the pdb-Format but are rather
inferred after reading the data into a system using the
FragmentDataBase:

``` julia
# bonds are not contained in the pdb
nbonds(s)

# use the fragment data base for normalizing naming schemas between molecular file formats, reconstruction of missing parts of the structure and building the bonds
fdb = FragmentDB()

normalize_names!(s, fdb)
reconstruct_fragments!(s, fdb)
build_bonds!(s, fdb)
nbonds(s)
```

Similar to the atom iteration, we can iterate over all bonds of a sysem:

``` julia
print.(b.order for b in bonds(s))
```

# How can I iterate over all bonds of an atom?

Or only iterate over the bonds of a specific atom:

``` julia
atom = atom_by_idx(s, 166) 
bds = filter(bond -> bond.a1 == atom.idx || bond.a2 == atom.idx, bonds(s))
println.(b for b in bds)
```

# How can I iterate over all chains of a system?

We can get the name and the number of atoms per chain by the following

``` julia
println.((chain.name, length(atoms(chain))) for chain in chains(s))
```

# How can I iterate over all chains of a molecule?

``` julia
println.((chain.name, length(atoms(chain))) for chain in chains(mol))
```

# How can I iterate over all residues of a system?

``` julia
println.(res.type for res in residues(s))

println.(res.chain_idx for res in fragments(s))
```

# How can I iterate over all residues of a chain?

``` julia
println.(res.type for res in residues(chain_by_idx(s,2)))
```
