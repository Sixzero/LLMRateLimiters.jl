using LLMRateLimiters
using Test
using Aqua

@testset "LLMRateLimiters.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(LLMRateLimiters)
    end

    include("test_rpm.jl")
    include("test_tpm.jl")
    include("test_header_ratelimits.jl")
    include("test_providers.jl")
    include("test_greedy_bpe_tokenizer.jl")
end;
