# Model to provider mapping
function get_provider(model::String)
    if model in ANTHROPIC_MODELS
        return Val(:anthropic), ANTHROPIC_RATE_LIMITER
    end
    Val(:no_provider_info), nothing
end

"""
    airatelimited(args...; model::String = "claudeh", kwargs...)

Dispatches to the appropriate provider's rate limited implementation based on the model.
"""
function airatelimited(args...; model::String = "claudeh", kwargs...)
    provider, rate_limiter = get_provider(model)
    airatelimited_byprovider(provider, args...; rate_limiter, model, kwargs...)
end

""" Fallback to simple aigenerate without ratelimit"""
function airatelimited_byprovider(provider::Val{:no_provider_info}, args...; rate_limiter, kwargs...)
    aigenerate(args...; kwargs...)
end