# §16.9.4 global edge-function probe

Host: DAN-DESKTOP, Slurm job 3191. Source under test: clean `main` commit
`c31cbf1b52f1a39d5775f276e2340525a444a79e`. Icarus SHA-256
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP
SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.

Command (for each edition):

```sh
iverilog -B "$TOOLCHAIN/lib/ivl" -g2017 -gassertions -s test -o probe.vvp p16_09_04_past_gclk_edge_funcs.sv
vvp -n probe.vvp
```

Both `-g2017` and `-g2023` compile with exit 0 and fail at runtime with exit 1.
The first check reports `$rose_gclk` false after a sampled 0-to-1 transition
(time 16000). The test therefore stops before checking the later stable/fall
calls. The copied VVP bytecode confirms these calls execute as VPI functions.
The SHA-256 metadata and raw compile/run logs are preserved in `results/`.

Source inspection of the same-main `vpi/sys_sva.c` shows `$rose_gclk`,
`$fell_gclk`, and `$stable_gclk` all use `sva_const_calltf`; that callback
returns 0 for each of these names (it returns 1 only for the distinct `$stable`
name). This explains why recognition by the compiler does not establish
conformance. A property-context probe is being run separately to verify the
three functions in their assertion use as well.
