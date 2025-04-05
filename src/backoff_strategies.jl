using Dates

"""
Abstract type for backoff strategies
"""
abstract type BackoffStrategy end

"""
No backoff strategy - maintains constant rate limiting
"""
struct NoBackoff <: BackoffStrategy end

"""
Exponential backoff strategy - increases wait time exponentially after 429 errors
"""
@kwdef mutable struct ExponentialBackoff <: BackoffStrategy
    backoff_factor::Float64 = 2.0  # Multiplier for each 429 encountered
    current_backoff::Float64 = 1.0  # Current backoff multiplier
    max_backoff::Float64 = 60.0  # Maximum backoff multiplier
    last_429_time::Union{DateTime, Nothing} = nothing  # Track when we last got a 429
    recovery_time::Float64 = 300.0  # Time in seconds before resetting backoff after no 429s
end

"""
Linear backoff strategy - increases wait time linearly after 429 errors
"""
@kwdef mutable struct LinearBackoff <: BackoffStrategy
    backoff_increment::Float64 = 0.5  # Amount to add for each 429 encountered
    current_backoff::Float64 = 1.0  # Current backoff multiplier
    max_backoff::Float64 = 10.0  # Maximum backoff multiplier
    last_429_time::Union{DateTime, Nothing} = nothing  # Track when we last got a 429
    recovery_time::Float64 = 300.0  # Time in seconds before resetting backoff after no 429s
end

# Default implementation for handling 429 errors
function handle_429!(strategy::NoBackoff)
    return 1.0  # No change to backoff
end

function handle_429!(strategy::ExponentialBackoff)
    strategy.current_backoff = min(strategy.current_backoff * strategy.backoff_factor, strategy.max_backoff)
    strategy.last_429_time = Dates.now()
    return strategy.current_backoff
end

function handle_429!(strategy::LinearBackoff)
    strategy.current_backoff = min(strategy.current_backoff + strategy.backoff_increment, strategy.max_backoff)
    strategy.last_429_time = Dates.now()
    return strategy.current_backoff
end

# Default implementation for getting current backoff
function get_current_backoff(strategy::NoBackoff, ::DateTime)
    return 1.0
end

function get_current_backoff(strategy::Union{ExponentialBackoff, LinearBackoff}, now::DateTime)
    if strategy.last_429_time !== nothing && 
       (now - strategy.last_429_time).value / 1000 > strategy.recovery_time
        strategy.current_backoff = 1.0
        strategy.last_429_time = nothing
        return 1.0
    end
    return strategy.current_backoff
end

# Calculate the actual wait time based on the backoff strategy
function calculate_wait_time(strategy::BackoffStrategy, base_wait_time::Float64)
    current_backoff = get_current_backoff(strategy, Dates.now())
    return base_wait_time * current_backoff
end
