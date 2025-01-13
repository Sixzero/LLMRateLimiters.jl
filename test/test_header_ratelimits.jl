using JSON3
using Test
using HTTP
using LLMRateLimiters: retry_on_rate_limit

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

        # Test non-standard 429 error
        function simulate_nonstandard_429()
            headers = ["content-type" => "application/json"]
            body = JSON3.write(Dict(:error => "Other error"))  # Simple string error
            throw(HTTP.StatusError(429, "POST", "/api", HTTP.Response(429, headers; body)))
        end

        @test_throws ErrorException retry_on_rate_limit(
            simulate_nonstandard_429;
            max_retries=2,
            verbose=false,
            base_wait_time=0.1
        )

        # Test server error (5xx)
        function simulate_server_error()
            headers = ["content-type" => "application/json"]
            body = JSON3.write(Dict(:error => "Server error"))
            throw(HTTP.StatusError(500, "POST", "/api", HTTP.Response(500, headers; body)))
        end

        @test_throws ErrorException retry_on_rate_limit(
            simulate_server_error;
            max_retries=2,
            verbose=false,
            base_wait_time=0.1
        )

        # Test other HTTP error
        function simulate_other_http_error()
            headers = ["content-type" => "application/json"]
            body = JSON3.write(Dict(:error => "Bad request"))
            throw(HTTP.StatusError(400, "POST", "/api", HTTP.Response(400, headers; body)))
        end

        @test_throws HTTP.StatusError retry_on_rate_limit(
            simulate_other_http_error;
            max_retries=2,
            verbose=false
        )

        # Test non-HTTP error
        function simulate_other_error()
            throw(ArgumentError("Invalid argument"))
        end

        @test_throws ArgumentError retry_on_rate_limit(
            simulate_other_error;
            max_retries=2,
            verbose=false
        )
    end
end
