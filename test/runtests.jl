using LLMRateLimiters
using Test
using Aqua
using Dates

@testset "LLMRateLimiters.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(LLMRateLimiters)
    end

    @testset "RPM Rate Limiter" begin
        @testset "Basic functionality" begin
            limiter = RateLimiterRPM(max_requests=2, time_window=1.0)
            counter = Ref(0)
            rate_limited_func = with_rate_limiter(limiter) do 
                (counter[] += 1)
            end
            
            # First two calls should be immediate
            t_start = time()
            rate_limited_func()
            rate_limited_func()
            t_elapsed = time() - t_start
            @test t_elapsed < 0.1
            @test counter[] == 2
            
            # Third call should be rate limited
            t_start = time()
            rate_limited_func()
            t_elapsed = time() - t_start
            @test t_elapsed ≈ 1.0 rtol=0.2
            @test counter[] == 3
        end
    end

    @testset "TPM Rate Limiter" begin
        @testset "Token estimation" begin
            @test estimate_tokens("test", CharCount) == 4
            @test estimate_tokens("test", CharCountDivTwo) == 2
            @test estimate_tokens("test test", WordCount) == 2
        end

        @testset "Basic functionality" begin
            limiter = RateLimiterTPM(
                max_tokens=10,
                time_window=1.0,
                estimation_method=CharCount
            )
            
            process = with_rate_limiter_tpm(limiter) do text
                return length(text)
            end
            
            # First call with small text should be immediate
            t_start = time()
            result = process("test")
            t_elapsed = time() - t_start
            @test t_elapsed < 0.1
            @test result == 4
            
            # Second call exceeding token limit should be rate limited
            t_start = time()
            result = process("test test test")  # 14 chars
            t_elapsed = time() - t_start
            @test t_elapsed ≈ 1.0 rtol=0.2
            @test result == 14
        end
        @testset "Oversized single request" begin
            limiter = RateLimiterTPM(
                max_tokens=5,  # Very small limit
                time_window=1.0,
                estimation_method=CharCount
            )
            
            process = with_rate_limiter_tpm(limiter) do text
                return length(text)
            end
            
            # Should allow oversized request when window is empty
            t_start = time()
            result = process("test test")  # 9 chars > 5 token limit
            t_elapsed = time() - t_start
            @test t_elapsed < 0.1
            @test result == 9
        end
    end

    @testset "Async functionality" begin
        limiter = RateLimiterRPM(max_requests=2, time_window=1.0)
        
        process = with_rate_limiter(x -> x, limiter)
        
        t_start = time()
        results = asyncmap(process, 1:4)
        t_elapsed = time() - t_start
        
        @test length(results) == 4
        @test t_elapsed ≈ 1.0 rtol=0.2  # Should take ~2 seconds for 4 items with limit of 1/sec
        @test sort(results) == [1,2,3,4]
    end
end;
