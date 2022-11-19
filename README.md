# Big O Benchmarker for Ruby

Have doubts about your big-o analysis? Use this benchmarking tool to see if you're analysis is reasonable.

How does it work? It finds the running time for different sample sizes n, creating data for the sample size with a function of your choice. It computes the actual time it takes to run the function, as well as the expected run time, based on various standard functions, like O(1), O(n), O(n^2), O(nlgn), etc. It then uses properties about the limits of f(n) (the actual running time) and g(n) (the function to compare) in order to guess the asymptotic running time. Namely, g(n) is an asymptotic upper bound (little o) of f(n) iff the limit of f(n)/g(n) equals zero, as n approaches infinity. g(n) is an asymptotic lower bound (little omega) of f(n) iff the limit of g(n)/f(n) equals positive infinity. If neither of these cases is true, and the limit of g(n)/f(n) approaches some nonzero constant k, then f(n) = theta(g(n)).

How do I use it?



