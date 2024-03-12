# System representation
```@meta
CurrentModule = BiochemicalAlgorithms
```

```@index
Pages = ["system.md"]
```

## Abstract types
```@docs
AbstractSystemComponent
AbstractAtomContainer
AbstractMolecule
```

## Common functions
```@docs
has_property
get_property
set_property!
has_flag
set_flag!
unset_flag!
```

## Systems
```@docs
System
default_system
Base.parent(::System)
parent_system
```

## Atoms
```@docs
Atom
atom_by_idx
atom_by_name
atoms
is_bound_to
is_geminal
is_vicinal
natoms
Base.push!(::System{T}, ::Atom{T}) where T
```

## Bonds
```@docs
Bond
bond_by_idx
bonds
nbonds
Base.push!(::System{T}, ::Bond{T}) where T
```

## Molecules
```@docs
Molecule
molecule_by_idx
molecules
nmolecules
parent_molecule
Base.push!(::System{T}, ::Molecule{T}) where T
```

## Chains
```@docs
Chain
chain_by_idx
chains
nchains
parent_chain
Base.push!(::Molecule{T}, ::Chain{T}) where T
```

## Fragments
```@docs
Fragment
fragment_by_idx
fragments
nfragments
parent_fragment
Base.push!(::Chain{T}, ::Fragment{T}) where T
```

## Nucleotides
```@docs
Nucleotide
nnucleotides
nucleotide_by_idx
nucleotides
parent_nucleotide
Base.push!(::Chain{T}, ::Nucleotide{T}) where T
```

## Residues
```@docs
Residue
nresidues
parent_residue
residue_by_idx
residues
Base.push!(::Chain{T}, ::Residue{T}) where T
```
