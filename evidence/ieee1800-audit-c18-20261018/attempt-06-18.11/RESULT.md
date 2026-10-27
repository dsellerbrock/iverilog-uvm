# IEEE 1800 §18.11 audit probe

- Standard scope: IEEE 1800-2017 and 1800-2023 §§18.11–18.11.1.
- Host: DAN-DESKTOP; Slurm job 2852, requested 1 CPU / 2 GiB.
- Toolchain: `/home/dsell/toolchains/iverilog-uvm-4bfe7d04`; hashes are in `results/tool-binaries.sha256`.
- Probe input hashes: `results/probe-inputs.sha256`.
- Raw compiler and runtime output: `results/`; scheduler stdout: `logs-a3-audit-c18-11-2852.out`.

The positive probe compiled and ran under both `-g2017` and `-g2023`, printing `PASS in-line random variable control clause 18.11` each time. It verified that `randomize(null)` returns 1 for a satisfied constraint and 0 for a violated constraint without changing fields; `randomize(x)` leaves omitted `y` unchanged and satisfies `x < v`; and `randomize(v)` solves a non-`rand` property.

The expected-negative cases did not reject compilation in either edition (all four compile exit codes were 0):

- `randomize(x + 1)` produced a `sorry` diagnostic saying the argument list is ignored and all `rand` properties are randomized, but compilation succeeded.
- `randomize(x)` from outside a class whose `x` is `local` compiled successfully without a randomize-specific diagnostic.

The harness therefore ended with `GATE_RESULT=FAIL` because both expected compile failures were accepted. This is a simulator behavior discrepancy, not a timeout or infrastructure failure. The invalid-list runtime fallback has not yet been separately probed; the audit lead will direct the next step.
