using LLMRateLimiters
using Dates

# Example 1: Basic RPM Rate Limiter
function basic_rpm_example()
    println("\n=== Basic RPM Rate Limiter ===")
    limiter = RateLimiterRPM(max_requests=5, time_window=5.0)
    
    # Wrap a simple function with rate limiting
    counter = Ref(0)
    rate_limited_func = with_rate_limiter(() -> (counter[] += 1; println("Request: $(counter[]) at $(now())")), limiter)
    
    # Make rapid requests
    for _ in 1:10
        rate_limited_func()
        sleep(0.1)
    end
end

# Example 2: TPM Rate Limiter
function tpm_example()
    println("\n=== TPM Rate Limiter ===")
    limiter = RateLimiterTPM(
        max_tokens = 100,
        time_window = 5.0,
        estimation_method = CharCountDivTwo
    )
    
    messages = [
        "Short message",
        "This is a longer message that will use more tokens",
        "Another message to test the rate limiting"
    ]
    
    process_message = with_rate_limiter_tpm(limiter) do msg
        println("Processing: '$msg' at $(now())")
        return "Processed: $msg"
    end
    
    for msg in messages
        process_message(msg)
        sleep(0.1)
    end
end

# Example 3: Async Rate Limiter Usage
function async_rpm_example()
    println("\n=== Async RPM Rate Limiter ===")
    limiter = RateLimiterRPM(max_requests=3, time_window=2.0)
    
    # Create rate limited function
    process_task = with_rate_limiter((id) -> println("Task $id processed at $(now())"), limiter)
    
    # Launch multiple async tasks
    @sync begin
        for i in 1:6
            @async begin
                process_task(i)
            end
        end
    end
end

# Example 4: Multiple Concurrent Tasks with TPM
function concurrent_tpm_example()
    println("\n=== Concurrent TPM Example ===")
    limiter = RateLimiterTPM(
        max_tokens = 50,
        time_window = 5.0,
        estimation_method = CharCountDivTwo
    )
    
    process_message = with_rate_limiter_tpm(limiter) do msg
        sleep(0.5)  # Simulate processing time
        println("Processed '$msg' at $(now())")
        return "Done: $msg"
    end
    
    messages = ["Task $i" for i in 1:8]
    
    # Process messages concurrently
    @sync begin
        for msg in messages
            @async process_message(msg)
        end
    end
end

# Run all examples
function run_all_examples()
    basic_rpm_example()
    sleep(1)
    tpm_example()
    sleep(1)
    async_rpm_example()
    sleep(1)
    concurrent_tpm_example()
end

# Run if file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_all_examples()
end
