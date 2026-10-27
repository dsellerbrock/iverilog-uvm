# Lead-directed §18.5.8 iterative-constraint probe

This probe covers dynamic-array `foreach` constraints, a conditional guard and ordering, two-dimensional arrays, array reduction with `sum() with`, and index expressions. Two negative cases check a loop variable with the same name as its array and more loop variables than array dimensions.

The open+closed issue searches and adjacent issue review are in `dedupe-open-closed.txt`. Both editions are compiled; the positive test runs only after successful compilation. Every compile/run gets a 20-second process-group timeout. Slurm request: one CPU, 1 GiB, 10 minutes; the prior full regression gate peaked at 437,536 KiB.
