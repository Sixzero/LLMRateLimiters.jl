using LLMRateLimiters
using LLMRateLimiters: GreedyBPETokenizer, load_bpe_tokenizer

"""
Example showing how to load and use all available tokenizer models from artifacts.
Also demonstrates how to determine the optimal size hints for each model.
"""

# List of all available models from Artifacts.toml
const AVAILABLE_MODELS = [
    "cl100k_base",  # ChatGPT/GPT-4
    "p50k_base",    # GPT-3 (davinci)
    "p50k_edit",    # GPT-3 (edit models)
    "r50k_base",    # GPT-2
    "o200k_base",   # Claude
    # "gpt2"          # Original GPT-2
]

function main()
    println("=== Tokenizer Models Size Measurement ===")
    
    # Measure size for each model
    model_sizes = Dict{String, Int}()
    
    for model in AVAILABLE_MODELS
        @time "$model" tokenizer = load_bpe_tokenizer(model)
    end
    
    return model_sizes
end

main()
