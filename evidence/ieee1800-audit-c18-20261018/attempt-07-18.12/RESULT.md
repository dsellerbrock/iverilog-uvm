# IEEE 1800 §18.12 audit probe

- Scope: IEEE 1800-2017 and 1800-2023 §§18.12–18.12.1.
- Host: DAN-DESKTOP; Slurm job 2873, requested 1 CPU / 2 GiB.
- Toolchain: `/home/dsell/toolchains/iverilog-uvm-4bfe7d04`; hashes in `results/tool-binaries.sha256`.
- Probe input hashes: `results/probe-inputs.sha256`.
- Raw compiler and runtime output: `results/`; scheduler stdout: `logs-a3-audit-c18-12-2873.out`.

The combined positive probe did not compile under either `-g2017` or `-g2023`: both zero-argument `std::randomize() with {...}` checker calls failed elaboration with `No function named 'std.randomize' found in this context`. As a result, earlier calls in the same file were not run and their runtime behavior remains unassessed by this attempt.

The negative `std::randomize(a + 1)` probe compiled successfully (exit 0) in both editions, contrary to the expected rejection. The harness ended with `GATE_RESULT=FAIL` for these observed conformance differences; no test timed out.
