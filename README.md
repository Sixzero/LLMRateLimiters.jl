# LLMRateLimiters [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sixzero.github.io/LLMRateLimiters.jl/dev/) [![Build Status](https://github.com/sixzero/LLMRateLimiters.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/sixzero/LLMRateLimiters.jl/actions/workflows/CI.yml?query=branch%3Amaster) [![Coverage](https://codecov.io/gh/sixzero/LLMRateLimiters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/sixzero/LLMRateLimiters.jl) [![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Rate limiting utilities for LLM services to prevent rate limit errors and manage API quotas. Aim is to be lightweight but useful.

## Features
- Request per minute (RPM) limiting `RateLimiterRPM`
- Token per minute (TPM) limiting `RateLimiterTPM`
- Async-safe rate limiting
- An opinionated rate limiting for Anthropic's Claude models

## Quick Start
```julia
using LLMRateLimiters

# RPM Rate Limiter
limiter = RateLimiterRPM(max_requests=60, time_window=60.0)
rate_limited_func = with_rate_limiter(your_api_call, limiter)

# TPM Rate Limiter
limiter = RateLimiterTPM(max_tokens=100000, time_window=60.0)
rate_limited_func = with_rate_limiter_tpm(your_llm_call, limiter)

# Built-in Claude rate limiting
result = airatelimited("What is 2+2?", model="claudeh")
```

## Installation
```julia
using Pkg
Pkg.add("LLMRateLimiters")
```

## Used by

[EasyContext.jl](https://github.com/Sixzero/EasyContext.jl)
and some minor projects.