# §8.27 parameterized forward class typedef (Slurm job 3506)

The probe is the IEEE example's forward typedef and parameterized class declaration, extended with construction and a typed member to make the specialization observable. The first harness selected the wrong module name; this run selects the declared `top` module. Both editions compile and run, but the observed member-size field differs from the lead's expected value.

- Host: DAN-DESKTOP; job 3506; 1 CPU, 1 GiB.
- Compiler: Icarus 13.0-devel `cc25756d1`; executable hashes are recorded in `results/SHA256SUMS`.
- Commands: `iverilog -g2017|-g2023 -s top ...`; each compile and run has a 30-second timeout.

| Edition | Compile | Run | Stdout | Harness expectation |
|---|---:|---:|---|---|
| 2017 | 0 | 0 | `FP 1 2 1` | `FP 1 2 64` |
| 2023 | 0 | 0 | `FP 1 2 1` | `FP 1 2 64` |

The mismatch may be in the added observability expression: IEEE 1800-2017/2023 §8.27's example demonstrates that the forward declaration may name a parameterized class and contains declarations only. It does not prescribe this `$bits(v2.t)` output. The raw evidence is preserved; ask the lead whether to replace this assertion with a standard-grounded observable before classifying §8.27.

Raw output: `results-3506.tar.gz`; source/binary hashes: `results/SHA256SUMS`; scheduler output: `logs/job-3506.out`.

Lead review: the `FP 1 2 1` versus `FP 1 2 64` mismatch is not evidence against §8.27. The lead confirms `$bits(real)` is not a valid expected value for this audit: §20.6.2 defines `$bits` around bit-stream expressions and references legal types in §6.24.3, which excludes `real`. The IEEE §8.27 example itself is declaration-only. The replacement probe in `attempt-03-fwd-param/` checks typed assignment directly and uses an `int` default-specialization control.
