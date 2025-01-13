
using Dates
using Base.Threads

@kwdef mutable struct RateLimiterTPM
    max_tokens::Int = 1_000_000
    time_window::Float64 = 60.0  # in seconds
    token_usage::Vector{Tuple{DateTime, Int}} = Tuple{DateTime, Int}[]
    lock::ReentrantLock = ReentrantLock()
    estimation_method::TokenEstimationMethod = CharCountDivTwo
    verbose::Bool = true
end

# Split rate limiting logic from function call
function check_and_wait!(limiter::RateLimiterTPM, input::Union{AbstractString, AbstractVector{<:AbstractString}})
    tokens = estimate_tokens(input, limiter.estimation_method)
    while true
        can_schedule = lock(limiter.lock) do
            now = Dates.now()
            filter!(t -> (now - t[1]).value / 1000 < limiter.time_window, limiter.token_usage)
            
            total_tokens = sum(last, limiter.token_usage, init=0)
            if isempty(limiter.token_usage) || total_tokens + tokens <= limiter.max_tokens
                push!(limiter.token_usage, (now, tokens))
                return true
            end
            limiter.verbose && @info "TPM Rate limit reached. Waiting..."
            return false
        end
        if can_schedule
            break
        end
        sleep(1)  # Wait if limit reached
    end
end

function with_rate_limiter_tpm(f::F, limiter::RateLimiterTPM) where {F}
    return function(input::Union{AbstractString, AbstractVector{<:AbstractString}}, args...; kwargs...)
        check_and_wait!(limiter, input)
        return f(input, args...; kwargs...)
    end
end

# Function to change the estimation method
function set_estimation_method!(limiter::RateLimiterTPM, method::TokenEstimationMethod)
    limiter.estimation_method = method
end

