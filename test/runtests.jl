using LLMRateLimiters
using Test
using Aqua
using Dates
using InteractiveUtils  # For @timed

@testset "LLMRateLimiters.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        # Aqua.test_all(LLMRateLimiters)
    end

    @testset "RPM Rate Limiter" begin
        @testset "Basic functionality" begin
            @timed limiter = RateLimiterRPM(max_requests=2, time_window=1.0, verbose=false)
            counter = Ref(0)
            rate_limited_func = with_rate_limiter(limiter) do
                (counter[] += 1)
            end
            
            # First two calls should be immediate
            result = @timed begin
                rate_limited_func()
                rate_limited_func()
            end
            @test result.time - result.compile_time < 0.2  # Test actual runtime
            @test counter[] == 2
            
            # Third call should be rate limited
            @time result2 = @timed rate_limited_func()
            # @info "1-2nd call" time=result.time compile_time=result.compile_time gctime=result.gctime recompile_time=result.recompile_time
            # @info "Third call" time=result2.time compile_time=result2.compile_time gctime=result2.gctime recompile_time=result2.recompile_time
            @test 1.1 > (result2.time - result2.compile_time) > 0.7 
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
                estimation_method=CharCount,
                verbose=false,
            )
            
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

    @testset "Async functionality" begin
        limiter = RateLimiterRPM(max_requests=2, time_window=1.0, verbose=false)
        process = with_rate_limiter(x -> x, limiter)
        
        result = @timed asyncmap(process, 1:4)
        
        @test length(result.value) == 4
        @test (result.time - result.compile_time) ≈ 1.0 rtol=0.2
        @test sort(result.value) == [1,2,3,4]
    end
end;
