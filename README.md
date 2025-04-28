# LLMRateLimiters [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sixzero.github.io/LLMRateLimiters.jl/dev/) [![Build Status](https://github.com/sixzero/LLMRateLimiters.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/sixzero/LLMRateLimiters.jl/actions/workflows/CI.yml?query=branch%3Amaster) [![Coverage](https://codecov.io/gh/sixzero/LLMRateLimiters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/sixzero/LLMRateLimiters.jl) [![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Rate limiting utilities for LLM services to prevent rate limit errors and manage API quotas. Aim is to be lightweight but useful.

## Features
- Request per minute (RPM) limiting `RateLimiterRPM`
- Token per minute (TPM) limiting `RateLimiterTPM`
- Async-safe rate limiting
- An opinionated rate limiting for Anthropic's Claude models
- Token count estimation methods:
    - `CharCount`, `CharCountDivTwo`, `WordCount`, `GPT2Approximation`
- Greedy BPE tokenizer for token counting (Julia port of [fast_bpe_tokenizer](https://github.com/youkaichao/fast_bpe_tokenizer))
    - **Within 1-2% (<10%) accuracy** of given tokenizers (e.g. **tiktoken**), while **10x faster!**

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

## Greedy BPE Tokenizer Usage
> **Note:** The tokenizer provides an approximation of model-specific tokenization. It uses greedy Byte Pair Encoding to break text into subword units, making it highly efficient for token counting and chunking.

```julia
using LLMRateLimiters
using LLMRateLimiters: load_bpe_tokenizer, encode, partial_encode!, EncodingStatePBE

# Load a tokenizer model (available models: cl100k_base, p50k_base, p50k_edit, r50k_base, o200k_base)
tokenizer = load_bpe_tokenizer("cl100k_base")  # ChatGPT/GPT-4 tokenizer

# Encode a string to tokens
tokens = encode(tokenizer, "Hello, world!")
println("Token count: $(length(tokens))")

# Process text in chunks with streaming support
# Perfect for large files or streaming data without reencoding previously processed text
text = "This is a long document that we want to process in chunks."
state = EncodingStatePBE()
state = partial_encode!(tokenizer, text[1:20], state)  # First chunk
state = partial_encode!(tokenizer, text[21:end], state)  # Second chunk
println("Total tokens: $(length(state.result))")

# Example with IO stream
open("large_document.txt") do file
    state = EncodingStatePBE()
    partial_encode!(tokenizer, file, state)
    println("Total tokens: $(length(state.result))")
end
```

## Installation
```julia
using Pkg
Pkg.add("LLMRateLimiters")
```

## Used by

[EasyContext.jl](https://github.com/Sixzero/EasyContext.jl)
and some minor projects.