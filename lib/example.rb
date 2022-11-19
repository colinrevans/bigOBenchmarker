require_relative "./benchmarker.rb"

bm = OrderBenchmarker
        .new                         # initialize benchmarker with default values, detailed below.
        .named("Array Sum")          # name the benchmarker, for informative printing
        .with_n_up_to(500000)            # choose the max sample size n
        .creating_inputs_with do |n| # tell it how to create data for the input size
          Array.new(n, rand(0..n)) 
        end
        .benchmarking do |arr|       # give it a function to measure
          arr.sum
        end
        .with_timeout(300)           # give it a number of seconds after which to stop benchmarking
        .benchmark_and_print         # run the benchmarker with feedback in the terminal


