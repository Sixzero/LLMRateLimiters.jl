using PrecompileTools

@setup_workload begin
    @compile_workload begin
        # RPM rate limiter with common types
        limiter_rpm = RateLimiterRPM(max_requests=3, time_window=0.05, verbose=false)
        f = with_rate_limiter(identity, limiter_rpm)
        f(1)  # Int
        f(1)  # Int
        f(1.0)  # Float64
        f("test")  # String
        f(["test"])  # Vector{String}
        # TPM rate limiter with common types
        limiter_tpm = RateLimiterTPM(max_tokens=100, time_window=1.0, verbose=false)
        g = with_rate_limiter_tpm(limiter_tpm) do text
            length(text)
        end
        g("test")  # String
        g(["test1", "test2"])  # Vector{String}
        
        # Token estimation for common types
        estimate_tokens("test string", CharCountDivTwo)
        estimate_tokens(["test1", "test2"], WordCount)
        estimate_tokens("test", CharCount)
    end
end