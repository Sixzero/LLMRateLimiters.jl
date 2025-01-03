using PrecompileTools

@setup_workload begin
    @compile_workload begin
        # Basic RPM rate limiter usage
        limiter_rpm = RateLimiterRPM(max_requests=5, time_window=1.0)
        f = with_rate_limiter(x -> x, limiter_rpm)
        f(1)
        f("test")

        # TPM rate limiter usage
        limiter_tpm = RateLimiterTPM(max_tokens=100, time_window=1.0)
        g = with_rate_limiter_tpm(x -> x, limiter_tpm)
        g("test string")
        g(["test1", "test2"])

        # Token estimation
        estimate_tokens("test string", CharCountDivTwo)
        estimate_tokens(["test1", "test2"], WordCount)
    end
end
