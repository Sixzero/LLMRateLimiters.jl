using LLMRateLimiters: get_provider, airatelimited_byprovider, update_rate_limiter!
using Test
using PromptingTools
using HTTP
using Dates

@testset "Provider-specific tests" begin
    @testset "Anthropic provider" begin
        @test get_provider("claude")[1] == Val(:anthropic)
        @test get_provider("claudeh")[1] == Val(:anthropic)
        @test get_provider("unknown")[1] == Val(:no_provider_info)

        # Test rate limiter update
        limiter = RateLimiterTPM(max_tokens=100_000, time_window=60.0)
        
        # Mock response with token usage
        mock_response = HTTP.Response(200, [
            "anthropic-ratelimit-tokens-limit" => "150000",
            "anthropic-ratelimit-tokens-reset" => "2024-12-31T23:59:59Z"
        ])

        response = AIMessage(
            content="test",
            tokens=(100, 50),  # prompt_tokens, completion_tokens
            elapsed=0.1,
            extras=Dict{Symbol,Any}(:response => mock_response),
            _type=:aimessage
        )

        # Test update_rate_limiter!
        update_rate_limiter!(Val(:anthropic), limiter, response)
        @test limiter.max_tokens == 150000
        @test !isempty(limiter.token_usage)
        @test last(limiter.token_usage)[2] == 150  # total tokens
    end

    @testset "Unknown model" begin
        test_input = "test message"
        result = airatelimited(test_input; rate_limiter=nothing, model="echo")
        @test result.content == "Hello!"
        @test result.status == 200
    end

    @testset "Fallback provider" begin
        test_input = "test message"
        result = airatelimited_byprovider(Val(:no_provider_info), test_input; rate_limiter=nothing, model="echo")
        @test result.content == "Hello!"
        @test result.status == 200
    end
end
