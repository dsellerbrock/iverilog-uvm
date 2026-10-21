# Clause 29 level-dominance control, rising edge

Attempt 04's falling-edge-only control produced `x`, so it did not establish that the competing edge row fired. This version uses a declared 0→1 clock, but the edge-only UDP still produced `x` because unmatched time-zero transitions were not recovered. It therefore does not establish dominance; see [`RESULT.md`](RESULT.md). Attempt 06 recovers state before testing the edge.

The standards basis is IEEE 1800-2017/2023 §§29.9–29.10. Raw job 3695 output is preserved in [`raw-slurm-3695/`](raw-slurm-3695/).
