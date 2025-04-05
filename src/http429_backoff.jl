using Dates
using HTTP

"""
HTTP429Backoff - A wrapper for backoff strategies specifically handling HTTP 429 errors
"""
@kwdef mutable struct HTTP429Backoff
    backoff_strategy::BackoffStrategy = NoBackoff()
    last_429_time::Union{DateTime, Nothing} = nothing
    recovery_time::Float64 = 300.0  # Time in seconds before resetting after no 429s
    min_request_interval::Float64 = 0.0  # Minimum time between requests after a 429
end

# Handle a 429 error
function handle_429!(backoff::HTTP429Backoff)
    backoff.last_429_time = Dates.now()
    return handle_429!(backoff.backoff_strategy)
end

# Calculate safety sleep time based on the backoff strategy
function calculate_safety_sleep(
    backoff::HTTP429Backoff, 
    now::DateTime, 
    last_request_time::Union{DateTime, Nothing},
    time_window::Float64,
    max_requests::Int
)
    # If no 429 has occurred or it's been a long time, no safety sleep
    if backoff.last_429_time === nothing
        return 0.0
    end
    
    # Calculate time since last 429
    time_since_429 = (now - backoff.last_429_time).value / 1000
    
    # If we've had a 429 within our recovery time, enforce a minimum interval
    if time_since_429 < backoff.recovery_time
        # Get current backoff multiplier
        current_backoff = get_current_backoff(backoff.backoff_strategy, now)
        
        # Calculate a dynamic minimum interval based on time window, max requests, and backoff
        dynamic_interval = (time_window / max_requests) * current_backoff
        
        # Apply minimum request interval if set
        if backoff.min_request_interval > 0
            dynamic_interval = max(dynamic_interval, backoff.min_request_interval)
        end
        
        # If we have a last request time, ensure we're spacing requests properly
        if last_request_time !== nothing
            time_since_last = (now - last_request_time).value / 1000
            
            if time_since_last < dynamic_interval
                return dynamic_interval - time_since_last
            end
        end
    end
    
    return 0.0
end

# Check if an exception is a HTTP 429 error
function is_http_429_error(e::Exception)
    return e isa HTTP.ExceptionRequest.StatusError && e.status == 429
end
