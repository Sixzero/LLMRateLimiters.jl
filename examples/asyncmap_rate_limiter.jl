using LLMRateLimiters
using Dates

function asyncmap_rpm_example()
    println()  # Add empty line at start
    println("=== AsyncMap RPM Example ===")
    limiter = RateLimiterRPM(max_requests=3, time_window=2.0)
    
    # Create rate limited function
    process_item = with_rate_limiter((id) -> begin
        println("Item $id processed at $(now())")
        sleep(0.2) # Simulate some work
        return "Result $id"
    end, limiter)
    
    # Process items with asyncmap
    items = 1:10
    results = asyncmap(process_item, items; ntasks=4)
    println("Results: ", results)
end

function asyncmap_tpm_example()
    println("\n=== AsyncMap TPM Example ===")
    limiter = RateLimiterTPM(
        max_tokens = 100,
        time_window = 2.0,
        estimation_method = CharCountDivTwo
    )
    
    messages = [
        "Task $i: Some text to process" 
        for i in 1:8
    ]
    
    process_message = with_rate_limiter_tpm(limiter) do msg
        println("Processing: '$msg' at $(now())")
        sleep(0.3) # Simulate processing
        return "Processed: $msg"
    end
    
    # Process with asyncmap
    results = asyncmap(process_message, messages; ntasks=3)
    println("Completed messages: ", length(results))
end

# Run examples
function run_examples()
    asyncmap_rpm_example()
    println("\nWaiting between examples...\n")
    # sleep(2)
    asyncmap_tpm_example()
end

run_examples()