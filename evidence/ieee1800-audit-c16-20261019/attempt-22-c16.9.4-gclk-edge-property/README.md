# §16.9.4 property-context edge-function probe

Host: DAN-DESKTOP, Slurm job 3192. Source under test: clean `main` commit
`c31cbf1b52f1a39d5775f276e2340525a444a79e`. Icarus SHA-256
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP
SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.

For each edition, the job compiled with `iverilog -g<edition> -gassertions`
and ran with `vvp -n`. Both `-g2017` and `-g2023` compiled with exit 0 and
reported the same property failures: `$rose_gclk` failed twice, while
`$stable_gclk` and `$fell_gclk` each failed once. The probe ends with the
expected nonzero exit after confirming all three behaviors were exercised.
Raw logs, bytecode, metadata, and tool/source hashes are in `results/`.

This complements job 3191's legal procedural calls. Along with the current-main
`vpi/sys_sva.c` mapping of all three names to a callback that returns constant
0 for these names, it confirms they are recognized but nonfunctional stubs in
both procedural and property contexts.
