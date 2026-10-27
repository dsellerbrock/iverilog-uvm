# §§16.9.8–16.9.10 corrected probes

Host: DAN-DESKTOP, Slurm job 3195. Source: clean `main`
`c31cbf1b52f1a39d5775f276e2340525a444a79e`; Icarus SHA-256
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP
SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.
Each source compiled with `iverilog -g<edition> -gassertions` and ran with
`vvp -n` under both `-g2017` and `-g2023`; all six compile/run pairs exited 0.

- §16.9.8 standalone `first_match` recognized one sequence match. This is an
  acceptance probe; it does not by itself prove earliest-match selection.
- §16.9.9 `throughout` accepted a condition held over a match and rejected a
  condition dropped on a wait cycle.
- §16.9.10 `within` matched the contained sequence at the outer match's start,
  middle, and end, and rejected an outer match with no contained match.

The separate §16.9.8 composition probe in attempt 23 was rejected by the
default assertion engine in both editions with a `sorry` for a variable-length
`first_match` feeding a continuation. Attempt 24 also found that a valid
sequence-match-item form is rejected by the parser; its raw input and logs are
preserved there. The audit lead is being asked to classify these limits and
file or deduplicate any issue before the matrix is finalized.

Inputs, compiler/input SHA-256 values, per-edition compile/run logs, VVP files,
and job metadata are preserved in `input/` and `results/`.
