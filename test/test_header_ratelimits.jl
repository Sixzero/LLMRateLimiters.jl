using JSON3

@testset "Header specific tests" begin
  @testset "Rate limit header handling" begin
    # Test with retry-after-ms header
    function simulate_rate_limited_call()
        headers = [
            "retry-after-ms" => "100",
            "content-type" => "application/json"
        ]
        body = JSON3.write(Dict(
            :error => Dict(
                :code => "rate_limit_exceeded",
                :message => "Too many requests"
            )
        ))
        throw(HTTP.StatusError(429, "POST", "/api", HTTP.Response(429, headers; body)))
    end

    # Should retry and eventually fail after max retries
    @test_throws ErrorException retry_on_rate_limit(
        simulate_rate_limited_call;
        max_retries=2,
        verbose=false,
        base_wait_time=0.1,
        default_retry_after=0.2
    )

    # Test without retry-after-ms header
    function simulate_rate_limited_no_header()
        headers = ["content-type" => "application/json"]
        body = JSON3.write(Dict(
            :error => Dict(
                :code => "rate_limit_exceeded",
                :message => "Too many requests"
            )
        ))
        throw(HTTP.StatusError(429, "POST", "/api", HTTP.Response(429, headers; body)))
    end

    @test_throws ErrorException retry_on_rate_limit(
        simulate_rate_limited_no_header;
        max_retries=2,
        verbose=false,
        base_wait_time=0.1,
        default_retry_after=0.2
    )
  end
end;