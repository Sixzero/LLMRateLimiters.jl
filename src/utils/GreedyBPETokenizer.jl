using Artifacts, LazyArtifacts
using Base64

struct GreedyBPETokenizer
  # 256‑ary trie in flat vectors exactly like the fast character tokenizer
  tokens      :: Vector{Int}          # child index or -1
  token_ids   :: Vector{Int}          # id of token that ends on this edge or -1
end

# Thread-safe singleton cache for tokenizers
const _TOKENIZER_CACHE = Dict{String, GreedyBPETokenizer}()
const _TOKENIZER_LOCK = ReentrantLock()

# Pre-determined size hints for known models to avoid resizing during loading
const MODEL_SIZE_HINTS = Dict{String, Int}(
    "cl100k_base" => 55488000,
    "p50k_base" => 25100288,
    "p50k_edit" => 25100288,
    "r50k_base" => 25094144,
    "o200k_base" => 107945216,
    "gpt2" => 25165824,
)

function GreedyBPETokenizer(path::String)
  tokens_raw = Vector{String}()
  ids_raw = Vector{Int32}()
  sizehint!(tokens_raw, 50000)
  sizehint!(ids_raw, 50000)
  
  max_id = Int32(0)
  total_bytes = 0
  
  # Determine model name from filename for size hints
  filename = basename(path)
  model_name = filename[1:end-length(".tiktoken")]
  
  open(path, "r") do io
      for line in eachline(io)
          parts = split(line)
          length(parts) < 2 && continue
          
          tok = String(base64decode(parts[1]))
          id = Int32(parse(Int, parts[2]))
          max_id = max(max_id, id)
          
          push!(tokens_raw, tok)
          push!(ids_raw, id)
          total_bytes += length(tok)
      end
  end
  
  char_vocab_size = 256
  
  # Use size hint from MODEL_SIZE_HINTS if available
  initial_size = get(MODEL_SIZE_HINTS, model_name, total_bytes + char_vocab_size)
  
  tokens = fill(Int32(-1), initial_size + char_vocab_size)
  token_ids = fill(Int32(-1), initial_size + char_vocab_size)
  
  next_free = Int32(char_vocab_size)
  is_slow_load = false
  
  @inbounds for i in eachindex(tokens_raw)
      tok = tokens_raw[i]
      id = ids_raw[i]
      node = Int32(0)
      bytes = codeunits(tok)
      
      for j in 1:length(bytes)
          b = bytes[j]
          slot = node + Int32(b) + 1
          
          if j == length(bytes)
              token_ids[slot] = id
          end
          
          child = tokens[slot]
          if child == -1
              child = next_free
              next_free += char_vocab_size
              
              if next_free + char_vocab_size > length(tokens)
                  !is_slow_load && println("Slightly slow loading, because we don't know the size of the vocabulary.")
                  is_slow_load = true
                  old_len = length(tokens)
                  new_len = cld(old_len * 3, 2)
                  resize!(tokens, new_len)
                  resize!(token_ids, new_len)
                  fill!(view(tokens, old_len+1:new_len), Int32(-1))
                  fill!(view(token_ids, old_len+1:new_len), Int32(-1))
              end
              
              tokens[slot] = child
          end
          
          node = child
      end
  end
    
  haskey(MODEL_SIZE_HINTS, model_name) && next_free != MODEL_SIZE_HINTS[model_name] && @warn "Vocabulary size mismatch for model $model_name (expected $(MODEL_SIZE_HINTS[model_name]), got $next_free)"
  resize!(tokens, next_free)
  resize!(token_ids, next_free)
  
  return GreedyBPETokenizer(tokens, token_ids)
end

"""
    load_bpe_tokenizer(name::String) -> GreedyBPETokenizer

Load a BPE tokenizer from the specified artifact name. Thread-safe and caches results.
"""
function load_bpe_tokenizer(name::String, verbose::Bool=false)
    lock(_TOKENIZER_LOCK) do
        if haskey(_TOKENIZER_CACHE, name)
            return _TOKENIZER_CACHE[name]
        end
        
        artifact_dir = try
            @artifact_str(name)
        catch e
            throw(ArgumentError("No tokenizer model named $name."))
        end
        
        path = joinpath(artifact_dir, "$name.tiktoken")
        tokenizer = verbose ? (@time "Loading tokenizer $name" GreedyBPETokenizer(path)) : GreedyBPETokenizer(path)
        _TOKENIZER_CACHE[name] = tokenizer
        return tokenizer
    end
end

"""
  encode(tok::GreedyBPETokenizer, text::String) -> Vector{Int}

Greedy left‑to‑right longest‑match tokenisation.  Linear in the number of
bytes of `text`.
"""
function encode(tok::GreedyBPETokenizer, text::String)
  isempty(text) && return Int[]

  bytes  = codeunits(text)
  tokens = tok.tokens
  ids    = tok.token_ids

  result               = Int[]
  sizehint!(result, length(text) ÷ 5)
  root                 = 0
  current_token_id     = -1
  last_found_pos       = -1
  last_found_token_id  = -1

  i = 1
  while i <= length(bytes)
      x = Int(bytes[i])
      should_backtrack = false

      if tokens[root + x + 1] != -1
          current_token_id = ids[root + x + 1]
          root             = tokens[root + x + 1]

          if current_token_id != -1
              last_found_pos      = i
              last_found_token_id = current_token_id
          end

          i += 1
          i > length(bytes) && (should_backtrack = true)
      else
          @assert last_found_pos != -1 "Tokenizer vocabulary is missing single‑byte tokens."
          should_backtrack = true
      end

      if should_backtrack
          push!(result, last_found_token_id)
          i    = last_found_pos + 1
          root = 0
          current_token_id    = -1
          last_found_pos      = -1
          last_found_token_id = -1
      end
  end

  return result
end

@kwdef mutable struct EncodingStatePBE
  result::Vector{Int}=Int[]       # Accumulated token IDs
  buffer::Vector{UInt8}=UInt8[]     # Buffer for bytes that haven't been fully processed
end

function partial_encode!(tok::GreedyBPETokenizer, text::AbstractString, state::EncodingStatePBE=EncodingStatePBE())
  partial_encode!(tok, codeunits(text), state)
end
function partial_encode!(tok::GreedyBPETokenizer, io::IO, state::EncodingStatePBE=EncodingStatePBE())
  # Read available data directly into a buffer
  chunk = read(io)
  partial_encode!(tok, chunk, state)
end
function partial_encode!(tok::GreedyBPETokenizer, chunk::Base.CodeUnits, state::EncodingStatePBE=EncodingStatePBE())
  tokens = tok.tokens
  ids = tok.token_ids
  
  # If we read 0 bytes and have no buffer, we're done
  if isempty(chunk)
      return state
  end
  
  # Append new chunk to any existing buffer
  append!(state.buffer, chunk)
  latest_token_found   = 0
  root                 = 0
  current_token_id     = -1
  last_found_pos       = -1
  last_found_token_id  = -1

  # Process bytes from the buffer
  i = 1
  while i <= length(state.buffer)
      x = Int(state.buffer[i])
      
      if tokens[root + x + 1] != -1
          current_token_id = ids[root + x + 1]
          root = tokens[root + x + 1]
          
          if current_token_id != -1
              last_found_pos = i
              last_found_token_id = current_token_id
          else
            # there is a chance there is a byte without id, but it might still have a token with the next char
          end
          
          i += 1
      else
          # Can't extend current token, need to backtrack
          if last_found_pos == -1
              error("Tokenizer vocabulary is missing single‑byte token: $x.")
          end
          push!(state.result, last_found_token_id)
          
          latest_token_found = last_found_pos
          # Move past the token we just processed
          i = last_found_pos + 1
          
          # Reset state for next token
          root = 0
          current_token_id = -1
          last_found_pos = -1
          last_found_token_id = -1
      end
  end
  
  if latest_token_found != 0
      # Keep any unprocessed bytes for the next chunk
      state.buffer = state.buffer[latest_token_found+1:end]
  end
  
  return state
end
