# Anthropic-specific rate limiting implementation
using Dates, HTTP

"""
    airatelimited_byprovider(args...; model::String = "claudeh", kwargs...)

A wrapper for `aigenerate` that automatically applies the appropriate rate limiter based on the model.

# Arguments
- `args...`: Arguments to be passed to `aigenerate`
- `model::String`: The model to use for generation. Defaults to "claudeh".
- `kwargs...`: Additional keyword arguments to be passed to `aigenerate`

# Returns
- The result of `aigenerate` after applying rate limiting
"""
function airatelimited_byprovider(provider::Val{:anthropic}, args...; model::String = "claudeh", rate_limiter, kwargs...)
    rate_limited_aigenerate = with_rate_limiter_tpm(aigenerate, rate_limiter)
    
    return retry_on_rate_limit(; max_retries=5, verbose=1) do
        response = rate_limited_aigenerate(args...; model=model, kwargs...)
        update_rate_limiter!(provider, rate_limiter, response)
        return response
    end
end

# Update the rate limiter based on the actual token usage
function update_rate_limiter!(::Val{:anthropic}, rate_limiter::RateLimiterTPM, response::PromptingTools.AIMessage, )
    actual_tokens = if response.tokens isa Tuple && length(response.tokens) >= 2
        response.tokens[1] + response.tokens[2]
    elseif response.tokens isa Dict && haskey(response.tokens, 1) && haskey(response.tokens, 2)
        response.tokens[1] + response.tokens[2]
    else
        return
    end

    lock(rate_limiter.lock) do
        !isempty(rate_limiter.token_usage) && pop!(rate_limiter.token_usage)
        push!(rate_limiter.token_usage, (Dates.now(), actual_tokens))
    end

    if haskey(response.extras, :response) && response.extras[:response] isa HTTP.Response
        headers = Dict(response.extras[:response].headers)
        if haskey(headers, "anthropic-ratelimit-tokens-limit")
            rate_limiter.max_tokens = parse(Int, headers["anthropic-ratelimit-tokens-limit"])
        end
        if haskey(headers, "anthropic-ratelimit-tokens-reset")
            reset_time = DateTime(headers["anthropic-ratelimit-tokens-reset"], "yyyy-mm-ddTHH:MM:SSZ")
            rate_limiter.time_window = (reset_time - now(UTC)).value / 1000.0
        end
    end
end

# Add model to provider mapping
const ANTHROPIC_MODELS = Set(["claude", "claudeh"])
# Create a global RateLimiterTPM instance
const ANTHROPIC_RATE_LIMITER = RateLimiterTPM(
    max_tokens = 400000,  # From anthropic-ratelimit-tokens-limit
    time_window = 60.0,   # Assuming the limit resets every minute
    estimation_method = CharCountDivTwo
)