
using Dates

# Create default instance
function create_anthropic_limiter()
    RateLimiterTPM(
        max_tokens = 400000,  # From anthropic-ratelimit-tokens-limit
        time_window = 60.0,   # Assuming the limit resets every minute
        estimation_method = CharCountDivTwo
    )
end

const MODEL_LIMITERS = Dict{String,RateLimiterTPM}()

function get_rate_limiter(model::String)
    get!(MODEL_LIMITERS, model) do
        create_anthropic_limiter()
    end
end

function airatelimited(args...; model::String = "claudeh", kwargs...)
    rate_limiter = get_rate_limiter(model)
    rate_limited_aigenerate = with_rate_limiter_tpm(aigenerate, rate_limiter)
    
    retry_on_rate_limit(; max_retries=5, verbose=1) do
        response = rate_limited_aigenerate(args...; model=model, kwargs...)
        update_rate_limiter!(rate_limiter, response)
        return response
    end
end

# Update the rate limiter based on the actual token usage
function update_rate_limiter!(rate_limiter::RateLimiterTPM, response)
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


