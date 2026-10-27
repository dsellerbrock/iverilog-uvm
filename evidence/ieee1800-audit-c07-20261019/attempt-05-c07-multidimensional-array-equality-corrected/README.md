# Clause 7.4 multidimensional unpacked-array equality

Slurm job 3225 compiled the corrected standard-valid probe using the pinned
Icarus 13.0 development toolchain from main
`c31cbf1b52f1a39d5775f276e2340525a444a79e` (iverilog SHA-256
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP
SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`).
It requested one CPU and 1 GiB with a 120-second compiler timeout.

IEEE 1800-2017 §7.4.3 and IEEE 1800-2023 §7.4.6 permit equality operations
on arrays; both clauses give array equality examples. The probe compares
two-dimensional unpacked arrays of identical shape and element type, then
changes one element and checks both `==` and `!=`.

In both editions, compile exits 4 with four diagnostics:

```text
error: Array left needs an array index here.
error: Array right needs an array index here.
error: Array left needs an array index here.
error: Array right needs an array index here.
```

The same operations on one-dimensional unpacked arrays pass in both editions
in job 3223. The harness recorded this targeted rejection as a completed
standard-gap probe and returned `OVERALL_RC=0`.

```text
Slurm job  3225
results-3225.tar.gz  e066507c8aa7f36ef6569af9e8911272c50f78f3f6c9ab6b49c339a104b525ec
input/probes.tar.gz  475f40e7a8f65169eda93b97d7c921de841b5e8f6c998e6bbd714ffc5a27e741
run.sbatch  6ebdfae03c01ee8cfd1c0a0098129b077f6df2915daa9c7b10707b3beb074e8b
```
