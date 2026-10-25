# §18.5.12 / §18.5.11 function constraints

IEEE 1800-2017 §18.5.12 (p. 521) and IEEE 1800-2023 §18.5.11 (p. 542) both say that functions run before constraint solving and that random variables passed as function arguments establish implicit variable priority. Higher-priority variables are solved first; their values and function results are state values for the remaining constraints.

The standard's `count_ones` example uses `length == count_ones(v)` and explains that this relation is not bidirectional: `v` is solved first, then `length` is determined. With `v` a random 10-bit value and `length < 3`, success therefore requires `popcount(v) < 3`, whose probability is `(1 + 10 + 45) / 1024 = 56 / 1024` (about 5.47%).

The 2017 text says, “Functions shall be called before constraints are solved”; it also says random function arguments establish an “implicit variable ordering or priority.” These two clauses are exercised by G1–G5.
