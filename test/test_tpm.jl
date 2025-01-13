using LLMRateLimiters
using LLMRateLimiters: set_estimation_method!
using Test
using Dates
using InteractiveUtils

@testset "TPM Rate Limiter" begin
    @testset "Token estimation" begin
        @test estimate_tokens("test", CharCount) == 4
        @test estimate_tokens("test", CharCountDivTwo) == 2
        @test estimate_tokens("test test", WordCount) == 2
        @test estimate_tokens("test", GPT2Approximation) == 2  # Added GPT2 test
        @test_throws ArgumentError estimate_tokens("test", TokenEstimationMethod(999))  # Test invalid method

        # Test vector input
        @test estimate_tokens(["test", "test"], CharCount) == 8
        @test estimate_tokens(["test", "word"], WordCount) == 2
    end

    @testset "Basic functionality" begin
        limiter = RateLimiterTPM(
            max_tokens=10,
            time_window=1.0,
            estimation_method=WordCount,
            verbose=false,
        )
        
        # Test estimation method change
        set_estimation_method!(limiter, CharCount)
        @test limiter.estimation_method == CharCount
        
        process = with_rate_limiter_tpm(limiter) do text
            return length(text)
        end
        
        # First call with small text should be immediate
        result = @timed process("test test")
        @test (result.time - result.compile_time) < 0.2
        @test result.value == 9
        
        # Second call exceeding token limit should be rate limited
        result = @timed process("test test test")  # 14 chars
        @test (result.time - result.compile_time) ≈ 1.0 rtol=0.2
        @test result.value == 14

        # Test with vector input
        result = @timed process(["test", "test"])
        @test result.value == 2
        
    end

    @testset "Oversized single request" begin
        limiter = RateLimiterTPM(
            max_tokens=5,  # Very small limit
            time_window=1.0,
            estimation_method=CharCount,
            verbose=false,
        )
        
        process = with_rate_limiter_tpm(limiter) do text
            return length(text)
        end
        
        result = @timed process("test test")  # 9 chars > 5 token limit
        @test (result.time - result.compile_time) < 0.1
        @test result.value == 9
    end
end
