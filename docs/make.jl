using LLMRateLimiters
using Documenter

DocMeta.setdocmeta!(LLMRateLimiters, :DocTestSetup, :(using LLMRateLimiters); recursive=true)

makedocs(;
    modules=[LLMRateLimiters],
    authors="SixZero <havliktomi@hotmail.com> and contributors",
    sitename="LLMRateLimiters.jl",
    format=Documenter.HTML(;
        canonical="https://Sixzero.github.io/LLMRateLimiters.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/sixzero/LLMRateLimiters.jl",
    devbranch="master",
)
