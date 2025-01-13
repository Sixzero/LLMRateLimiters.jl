module LLMRateLimiters

using PromptingTools
using PrecompileTools

include("utils/TokenEstimationMethods.jl")
include("RateLimiterRPM.jl")
include("RateLimiterHeader.jl")
include("RateLimiterTPM.jl")
include("providers.jl")  
include("providers/anthropic.jl")
include("precompile.jl")

export 
    # Rate Limiters
    RateLimiterRPM,
    RateLimiterTPM,
    with_rate_limiter,
    with_rate_limiter_tpm,
    retry_on_rate_limit,
    airatelimited,
    
    # Token Estimation
    TokenEstimationMethod,
    CharCount,
    CharCountDivTwo,
    WordCount,
    GPT2Approximation,
    estimate_tokens

end
