using Dates
using Base.Threads

@kwdef mutable struct RateLimiterRPM
    max_requests::Int = 60
    time_window::Float64 = 60.0
    request_times::Vector{DateTime} = DateTime[]
    lock::ReentrantLock = ReentrantLock()
    verbose::Bool = true
end

# Split the rate limiting logic from the function call
function check_and_wait!(limiter::RateLimiterRPM)
    lock(limiter.lock) do
        now = Dates.now()
        filter!(t -> (now - t).value / 1000 < limiter.time_window, limiter.request_times)
        
        if length(limiter.request_times) >= limiter.max_requests
            sleep_time = limiter.time_window - (now - limiter.request_times[1]).value / 1000
            limiter.verbose && @info "RPM Rate limit reached. Sleeping for $sleep_time seconds."
            sleep(max(0, sleep_time))
            empty!(limiter.request_times)
        end
        
        push!(limiter.request_times, Dates.now())
    end
end

function with_rate_limiter(f::F, limiter::RateLimiterRPM) where {F}
    return function(args...)
        check_and_wait!(limiter)
        return f(args...)
    end
end
