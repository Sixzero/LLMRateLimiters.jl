using Dates
using Base.Threads

@kwdef mutable struct RateLimiterRPM
    max_requests::Int = 60
    time_window::Float64 = 60.0
    request_times::Vector{DateTime} = DateTime[]
    lock::ReentrantLock = ReentrantLock()
    verbose::Bool = true
    http429_backoff::Union{HTTP429Backoff, Nothing} = nothing
end

# Split the rate limiting logic from the function call
function check_and_wait!(limiter::RateLimiterRPM)
    lock(limiter.lock) do
        now = Dates.now()
        filter!(t -> (now - t).value / 1000 < limiter.time_window, limiter.request_times)
        
        # Apply HTTP 429 backoff safety sleep if configured
        if limiter.http429_backoff !== nothing
            # Get the last request time if available
            last_request_time = isempty(limiter.request_times) ? nothing : limiter.request_times[end]
            
            # Calculate safety sleep based on HTTP 429 backoff
            safety_sleep = calculate_safety_sleep(
                limiter.http429_backoff, 
                now, 
                last_request_time, 
                limiter.time_window, 
                limiter.max_requests
            )
            
            # Sleep for safety period if needed
            if safety_sleep > 0
                limiter.verbose && @info "HTTP 429 safety sleep: $safety_sleep seconds"
                sleep(safety_sleep)
                now = Dates.now()  # Update now after sleeping
            end
        end
        
        if length(limiter.request_times) >= limiter.max_requests
            sleep_time = limiter.time_window - (now - limiter.request_times[1]).value / 1000
            limiter.verbose && @info "RPM Rate limit reached. Sleeping for $sleep_time seconds."
            sleep(max(0, sleep_time))
            popfirst!(limiter.request_times)
        end
        
        push!(limiter.request_times, Dates.now())
    end
end

function with_rate_limiter(f::F, limiter::RateLimiterRPM) where {F}
    return function(args...)
        check_and_wait!(limiter)
        try
            return f(args...)
        catch e
            if limiter.http429_backoff !== nothing && is_http_429_error(e)
                # Apply HTTP 429 backoff strategy
                lock(limiter.lock) do
                    new_backoff = handle_429!(limiter.http429_backoff)
                    limiter.verbose && @info "Received HTTP 429 error, adjusting backoff to $(new_backoff)x"
                end
            end
            rethrow(e)
        end
    end
end
