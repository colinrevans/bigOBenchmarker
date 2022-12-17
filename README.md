# Big O Benchmarker for Ruby

Finds the running time for different sample sizes n, creating data for the sample size with a function of your choice. It computes the actual time it takes to run the function, as well as the expected run time, based on various canonical functions, like O(1), O(n), O(n^2), O(nlgn), etc. It then uses properties about the limits of f(n) (the actual running time) and g(n) (the function to compare) in order to guess the asymptotic running time. Namely, g(n) is an asymptotic upper bound (little o) of f(n) iff the limit of f(n)/g(n) equals zero, as n approaches infinity. g(n) is an asymptotic lower bound (little omega) of f(n) iff the limit of g(n)/f(n) equals positive infinity. If neither of these cases is true, and the limit of g(n)/f(n) approaches some nonzero constant k, then f(n) = theta(g(n)).

How do I use it?

Create a benchmarker and set it up with two things: the function to measure, and the way to create data from each sample size n. Eg, to test the asymptotic running time of Array.sum, up to an array of 500 elements:

```ruby
bm = OrderBenchmarker
        .new                         # initialize benchmarker with default values, detailed below.
        .named("Array Sum")          # name the benchmarker, for informative printing
        .with_n_up_to(500000)        # choose the max sample size n
        .creating_inputs_with do |n| # tell it how to create data for the input size
          Array.new(n, rand(0..n)) 
        end
        .benchmarking do |arr|       # give it a function to measure
          arr.sum
        end
        .with_timeout(300)           # give it a number of seconds after which to stop benchmarking
        .benchmark_and_print         # run the benchmarker with feedback in the terminal

```

Run ruby lib/example.rb to see it in action.


Nonsense output? Try a higher n value.

Bored? Ctrl-C stops the benchmarker, gives you the current results, and lets you keep going if you want to.
