using Test
using LLMRateLimiters
using LLMRateLimiters: GreedyBPETokenizer, load_bpe_tokenizer, encode, partial_encode!, EncodingStatePBE

@testset "GreedyBPETokenizer" begin
    # Test loading from artifact
    @testset "Tokenizer loading" begin
        # Test loading a known model
        tokenizer = load_bpe_tokenizer("cl100k_base")
        @test tokenizer isa GreedyBPETokenizer
        
        # Test caching - second load should be fast and return same instance
        tokenizer2 = load_bpe_tokenizer("cl100k_base")
        @test tokenizer === tokenizer2
        
        # Test error for unknown model
        @test_throws ArgumentError load_bpe_tokenizer("nonexistent_model")
    end
    
    @testset "Basic encoding" begin
        tokenizer = load_bpe_tokenizer("cl100k_base")
        
        # Test empty string
        @test encode(tokenizer, "") == Int[]
        
        # Test simple strings
        hello_tokens = encode(tokenizer, "Hello, world!")
        @test length(hello_tokens) > 0
        @test hello_tokens isa Vector{Int}
        
        # Test longer text
        lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
        lorem_tokens = encode(tokenizer, lorem)
        @test length(lorem_tokens) > 0
        @test length(lorem_tokens) < length(lorem)  # Should be more efficient than char-by-char
    end
    
    @testset "Partial encoding" begin
        tokenizer = load_bpe_tokenizer("cl100k_base")
        
        # Test partial encoding with string chunks
        text = "This is a test of partial encoding functionality."
        
        # Split into chunks
        chunk1 = text[1:10]  # "This is a "
        chunk2 = text[11:20] # "test of pa"
        chunk3 = text[21:end] # "rtial encoding functionality."
        
        # Process chunks sequentially
        state = EncodingStatePBE()
        
        # Process first chunk
        state = partial_encode!(tokenizer, chunk1, state)
        tokens1 = copy(state.result)
        @test length(tokens1) > 0
        
        # Process second chunk
        prev_token_count = length(state.result)
        state = partial_encode!(tokenizer, chunk2, state)
        tokens2 = state.result[prev_token_count+1:end]
        
        # Process third chunk
        prev_token_count = length(state.result)
        state = partial_encode!(tokenizer, chunk3, state)
        tokens3 = state.result[prev_token_count+1:end]
        @test length(tokens3) > 0
        
        # Compare with full encoding
        full_tokens = encode(tokenizer, text)
        @test state.result == full_tokens[1:end-1] || state.result == full_tokens
        
        # Test with empty chunk
        state = EncodingStatePBE()
        state = partial_encode!(tokenizer, "", state)
        @test state.result == Int[]
    end
    
    @testset "Thread safety" begin
        # Test concurrent loading of tokenizers
        results = Vector{Any}(undef, 10)
        
        Threads.@threads for i in 1:10
            results[i] = load_bpe_tokenizer("cl100k_base")
        end
        
        # All results should be the same instance
        for i in 2:10
            @test results[i] === results[1]
        end
    end
end
