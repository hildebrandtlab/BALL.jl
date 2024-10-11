using BiochemicalAlgorithms
using Documenter

DocMeta.setdocmeta!(BiochemicalAlgorithms, :DocTestSetup, :(using BiochemicalAlgorithms); recursive=true)

const pages = Any[
    "Home" => "index.md",
    "Tutorials" => [
        "How to get started" => "tutorials/getting_started.md",
        "How to iterate" => "tutorials/iterate.md",
        "How to read and write" => "tutorials/read_and_write.md",
        "How to handle molecules" =>"tutorials/handle_molecules.md"
    ],
    "Library" => Any[
        "Biomolecular systems" => "public/system.md",
        "Force fields" => "public/forcefields.md",
        "Mappings" => "public/mappings.md",
        "Internals" => Any[
            "Biomolecular systems" => "private/system.md"
            "Mappings" => "private/mappings.md"
        ]
    ]
]

makedocs(;
    modules=[BiochemicalAlgorithms],
    authors="Andreas Hildebrandt <andreas.hildebrandt@uni-mainz.de> and contributors",
    repo=Remotes.GitHub("hildebrandtlab", "BiochemicalAlgorithms.jl"),
    sitename="BiochemicalAlgorithms.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://hildebrandtlab.github.io/BiochemicalAlgorithms.jl",
        assets=String[],
    ),
    pages = pages,
)

deploydocs(;
    repo="github.com/hildebrandtlab/BiochemicalAlgorithms.jl",
    devbranch="develop",
)
