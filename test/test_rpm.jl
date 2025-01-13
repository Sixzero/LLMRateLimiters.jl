using LLMRateLimiters
using Test
using Dates
using InteractiveUtils

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
        result2 = @timed rate_limited_func()
        @test 1.1 > (result2.time - result2.compile_time) > 0.7 
        @test counter[] == 3
    end

    @testset "Async functionality" begin
        limiter = RateLimiterRPM(max_requests=2, time_window=1.0, verbose=false)
        process = with_rate_limiter(x -> x, limiter)
        
        result = @timed asyncmap(process, 1:4)
        
        @test length(result.value) == 4
        @test (result.time - result.compile_time) ≈ 1.0 rtol=0.2
        @test sort(result.value) == [1,2,3,4]
    end
end
