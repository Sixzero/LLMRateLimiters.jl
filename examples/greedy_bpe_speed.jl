using PyCall
using LLMRateLimiters
using LLMRateLimiters: CharCountDivTwo, load_bpe_tokenizer, encode
using DataFrames
using PrettyTables

# Load the tiktoken Python library
tiktoken = pyimport("tiktoken")

# Load our tokenizer
vocab_file = "cl100k_base"
println("Loading Greedy BPE tokenizer...")
@time greedy_bpe_tokenizer = load_bpe_tokenizer(vocab_file)
@time encoding = tiktoken.get_encoding(vocab_file)

function compare_tokenizers(text)
    # Time our GreedyBPE tokenizer
    greedy_time = @elapsed begin
        greedy_tokens = encode(greedy_bpe_tokenizer, text)
        greedy_count = length(greedy_tokens)
    end
    
    # Time Python's tiktoken
    tiktoken_time = @elapsed begin
        py_tokens = encoding.encode(text)
        tiktoken_count = length(py_tokens)
    end
    
    # Time CharCountDivTwo estimation
    char_div_two_time = @elapsed begin
        char_div_two_count = LLMRateLimiters.estimate_tokens(text, CharCountDivTwo)
    end
    
    return greedy_count, tiktoken_count, char_div_two_count, greedy_time, tiktoken_time, char_div_two_time
end

function main()
    # Find files to process (max 100)
    files = String[]
    parent_dir = dirname(pwd())
    
    # Walk through parent directory and collect files
    for (root, dirs, filenames) in walkdir(parent_dir)
        for filename in filenames
            # Skip binary files and very large files
            if endswith(lowercase(filename), ".txt") || 
               endswith(lowercase(filename), ".md") || 
               endswith(lowercase(filename), ".py") || 
               endswith(lowercase(filename), ".jl") || 
               endswith(lowercase(filename), ".json")
                
                filepath = joinpath(root, filename)
                filesize = stat(filepath).size
                
                # Skip files larger than 1MB
                if filesize < 1_000_000 && filesize > 10_000
                    push!(files, filepath)
                    length(files) >= 100 && break
                end
            end
        end
        length(files) >= 1000 && break
    end
    
    println("Found $(length(files)) files to process")
    
    # Process each file and compare tokenizers
    results = []
    
    for (i, file) in enumerate(files)
        try
            text = read(file, String)
            greedy_count, tiktoken_count, char_div_two_count, greedy_time, tiktoken_time, char_div_two_time = compare_tokenizers(text)
            
            # Calculate difference percentages
            greedy_diff_pct = abs(greedy_count - tiktoken_count) / max(1, tiktoken_count) * 100
            char_div_two_diff_pct = abs(char_div_two_count - tiktoken_count) / max(1, tiktoken_count) * 100
            
            speed_ratio = tiktoken_time / max(greedy_time, 1e-10)
            char_div_two_speed_ratio = tiktoken_time / max(char_div_two_time, 1e-10)
            
            push!(results, (
                file=basename(file), 
                greedy_count=greedy_count, 
                tiktoken_count=tiktoken_count,
                char_div_two_count=char_div_two_count,
                greedy_diff=greedy_count - tiktoken_count,
                char_div_two_diff=char_div_two_count - tiktoken_count,
                greedy_diff_pct=greedy_diff_pct,
                char_div_two_diff_pct=char_div_two_diff_pct,
                greedy_time=greedy_time,
                tiktoken_time=tiktoken_time,
                char_div_two_time=char_div_two_time,
                greedy_speed_ratio=speed_ratio,
                char_div_two_speed_ratio=char_div_two_speed_ratio
            ))
            
            println("[$i/$(length(files))] $(basename(file)): " *
                   "GreedyBPE: $greedy_count tokens in $(round(greedy_time*1000, digits=2))ms ($(round(greedy_diff_pct, digits=2))%), " *
                   "Tiktoken: $tiktoken_count tokens in $(round(tiktoken_time*1000, digits=2))ms, " *
                   "CharDiv2: $char_div_two_count tokens in $(round(char_div_two_time*1000, digits=2))ms ($(round(char_div_two_diff_pct, digits=2))%)")
        catch e
            println("Error processing file $(file): $e")
        end
    end
    
    # Summary statistics
    if !isempty(results)
        total_greedy = sum(r.greedy_count for r in results)
        total_tiktoken = sum(r.tiktoken_count for r in results)
        total_char_div_two = sum(r.char_div_two_count for r in results)
        
        total_greedy_time = sum(r.greedy_time for r in results)
        total_tiktoken_time = sum(r.tiktoken_time for r in results)
        total_char_div_two_time = sum(r.char_div_two_time for r in results)
        
        avg_greedy_diff_pct = sum(r.greedy_diff_pct for r in results) / length(results)
        avg_char_div_two_diff_pct = sum(r.char_div_two_diff_pct for r in results) / length(results)
        
        avg_greedy_speed_ratio = sum(r.greedy_speed_ratio for r in results) / length(results)
        avg_char_div_two_speed_ratio = sum(r.char_div_two_speed_ratio for r in results) / length(results)
        
        println("\nSummary:")
        println("Total tokens (GreedyBPE): $total_greedy in $(round(total_greedy_time, digits=4))s")
        println("Total tokens (Tiktoken): $total_tiktoken in $(round(total_tiktoken_time, digits=4))s")
        println("Total tokens (CharDiv2): $total_char_div_two in $(round(total_char_div_two_time, digits=4))s")
        println("Average difference (GreedyBPE): $(round(avg_greedy_diff_pct, digits=2))%")
        println("Average difference (CharDiv2): $(round(avg_char_div_two_diff_pct, digits=2))%")
        println("Average speed ratio (Tiktoken/GreedyBPE): $(round(avg_greedy_speed_ratio, digits=2))x")
        println("Average speed ratio (Tiktoken/CharDiv2): $(round(avg_char_div_two_speed_ratio, digits=2))x")
        
        # Create DataFrames for different views of the data
        df = DataFrame(results)
        
        # Token count comparison DataFrame
        token_df = select(df, 
            :file, 
            :tiktoken_count, 
            :greedy_count, 
            :char_div_two_count, 
            :greedy_diff, 
            :char_div_two_diff, 
            :greedy_diff_pct, 
            :char_div_two_diff_pct
        )
        
        # Timing comparison DataFrame
        time_df = select(df, 
            :file, 
            :tiktoken_time => ByRow(t -> round(t*1000, digits=2)) => :tiktoken_ms,
            :greedy_time => ByRow(t -> round(t*1000, digits=2)) => :greedy_ms,
            :char_div_two_time => ByRow(t -> round(t*1000, digits=2)) => :char_div_two_ms,
            :greedy_speed_ratio => ByRow(r -> round(r, digits=2)) => :greedy_speed_ratio,
            :char_div_two_speed_ratio => ByRow(r -> round(r, digits=2)) => :char_div_two_speed_ratio
        )
        
        # Display token count comparison table
        println("\nToken Count Comparison (sorted by tiktoken count):")
        sort!(token_df, :tiktoken_count, rev=true)
        pretty_table(token_df, 
            formatters = (v,i,j) -> (j in [7,8] ? string(round(v, digits=2), "%") : v),
            header = ["File", "Tiktoken", "GreedyBPE", "CharDiv2", "GreedyDiff", "CharDiv2Diff", "GreedyDiff%", "CharDiv2Diff%"]
        )
        
        # Display timing comparison table
        println("\nTiming Comparison (sorted by tiktoken time):")
        sort!(time_df, :tiktoken_ms, rev=true)
        pretty_table(time_df,
            formatters = (v,i,j) -> (j in [2,3,4] ? string(v, "ms") : (j in [5,6] ? string(v, "x") : v)),
            header = ["File", "Tiktoken", "GreedyBPE", "CharDiv2", "GreedyRatio", "CharDiv2Ratio"]
        )
        
        # Find files with largest differences for GreedyBPE
        println("\nTop 5 files with largest token count differences (GreedyBPE):")
        sort!(results, by = r -> r.greedy_diff_pct, rev=true)
        for i in 1:min(5, length(results))
            r = results[i]
            println("$(r.file): GreedyBPE: $(r.greedy_count), Tiktoken: $(r.tiktoken_count), " *
                   "Diff: $(r.greedy_diff) ($(round(r.greedy_diff_pct, digits=2))%)")
        end
        
        # Find files with largest speed differences for GreedyBPE
        println("\nTop 5 files with largest speed differences (GreedyBPE):")
        sort!(results, by = r -> r.greedy_speed_ratio, rev=true)
        for i in 1:min(5, length(results))
            r = results[i]
            println("$(r.file): GreedyBPE: $(round(r.greedy_time*1000, digits=2))ms, " *
                   "Tiktoken: $(round(r.tiktoken_time*1000, digits=2))ms, " *
                   "Ratio: $(round(r.greedy_speed_ratio, digits=2))x")
        end

    end
end

# Run the comparison
main()