# IEEE 1800 §22.12 line directive probe

## Standard basis

IEEE 1800-2017 §22.12 and IEEE 1800-2023 §22.12 specify the same syntax:
```
`line number "filename" level
```
The number is positive; the level is 0, 1, or 2. The directive sets the
following source line and filename, and the compiler advances the line as it
reads later text. Both editions include the same enter/exit include-level
meanings and require source file/line information to be available for PLI.

## Probe and result

- Existing regression: [`fileline2.v`](../../../ivtest/ivltests/fileline2.v), registered as `fileline2` in `ivtest/regress-sv.list` with [`fileline2.gold`](../../../ivtest/gold/fileline2.gold).
- The test applies levels 0, 1, and 2 at lines 1000, 2000, and 3000, checks `__LINE__`, and prints `__FILE__`/`__LINE__` for each mapping.
- Slurm job 3601 used current-main toolchain commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel), 1 CPU, 1 GiB, and a 5-minute allocation. `iverilog -g2012 -s aaa` compilation, VVP execution, and full output comparison against the checked-in golden all passed. Each test command had a 30-second timeout.
- This initial run used `-g2012`. The current-main compiler’s `-g2017` and `-g2023` modes were verified in the paired-edition follow-up, [Slurm job 3604](../../../evidence/ieee1800-audit-c22-20261021/attempt-02-paired-editions/RESULT.md).
- Source SHA-256: `7399304b376fc6e745053641f63165ba480b980961859c3afa250bcbac63f743`; golden SHA-256: `c639954bc258a3ad8ca5f0991531e3a3199df5689a0a4ceaaa7daf0c797e8460`.
- Raw Slurm output, stdout, and stderr are retained in [`remote-3601/`](remote-3601/). Compile and runtime stderr were empty; output was exactly the golden.

## Dedupe and lead status

The open and closed `1800-audit` issue-title search found no existing §22.12 line-directive gap. The probe passes, so no issue was proposed. The matrix row remains lead-pending because the helper reports “daily lead cap reached (160)”.
