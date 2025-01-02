using LLMRateLimiters
using Test
using Aqua

@testset "LLMRateLimiters.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(LLMRateLimiters)
    end
    # Write your tests here.
end
