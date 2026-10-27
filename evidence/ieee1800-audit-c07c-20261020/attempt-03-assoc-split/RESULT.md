# Split associative-array probe results

## Standards text

- IEEE 1800-2017 §7.8.3 p. 156 and IEEE 1800-2023 §7.8.3 p. 164: “A null index is valid.”
- IEEE 1800-2017 §7.8.5 p. 156 and IEEE 1800-2023 §7.8.5 p. 165: “Declared indices shall have the equality operator defined for its type to be legal.” Both editions also show an unpacked `struct` as an associative-array index example; real/shortreal types and types containing them are prohibited. Probe `U` contains only `byte` and `int` members.
- The clauses agree for these probes. These excerpts confirm null class indices and the struct-key test are within the stated legal domain.

## Toolchain and command

- Source: archived clean IEEE-audit baseline `cc25756d187314742d347267c2a513b3e640a7fb`; no simulator source was modified. Icarus 13.0-devel was built on Mac with Bison 3.8.2 and Homebrew libffi/Z3 headers.
- Binaries: `iverilog` SHA-256 `5e3aecaddb84174c5d9151a24e627c61b418f53b741c5b9bc3ce400bc03414e4`; `vvp` SHA-256 `8f9c3fe2e0812520733c6eae38e4226d8501b5ed4a4f3b53bfcbb7538bceb3f8`.
- Host: Darwin arm64, `MacBook-Air.local`. Local `localrun` supervised the build and bounded each compile/runtime invocation to 30 seconds. The completion/install/probe phase took 45.17 seconds and peaked at 845,430,784 bytes RSS; `localrun-final-04.log` records the wrapper report and tool hashes.
- Each probe used `iverilog -g2017` or `iverilog -g2023` with `-s <top>`, then `vvp <binary>`. Full source and isolated stdout/stderr/resource logs are in `tests/1800_audit/c07/a[1-6]_*.sv` and `local-results/`.
- A Linux Slurm run of the combined probe was job 3515, Icarus `cc25756d1`: positive compile rc 0 in both editions, `vvp` segfault rc 139 before output. Its raw logs are in the preceding attempt. Slurm job 3517 for the split was cancelled while pending (`Reason=Resources`, 38,912 MiB allocated of 39,101 MiB); it produced no test result.

## Results by feature

| File | 2017 | 2023 |
|---|---|---|
| `a1_class_assoc_keys.sv` | compile/run rc 0; `BEGIN a1`, `A1 2 1 2` | same |
| `a2_derived_assoc_key.sv` | compile/run rc 0; `BEGIN a2`, `A2 3 3` | same |
| `a3_null_assoc_key.sv` | compile/run rc 0; `BEGIN a3`, `A3 1 4` | same |
| `a4_struct_assoc_key.sv` | compile rc 0; runtime rc 139 (SIGSEGV) after `BEGIN a4`; no result line | compile rc 0; runtime rc 138 (SIGBUS) after `BEGIN a4`; no result line |
| `a5_assoc_array_assignment.sv` | compile/run rc 0; `BEGIN a5`, `A5 1 9` | same |
| `a6_assoc_array_args.sv` | compile/run rc 0; copy `1 9`, by-value `1`, ref `200` | same |

The lead's a2 operation inserts two base keys and one derived key, then prints `ak[kd], ak.size()`. The observed and semantically consistent output is `3 3`; the earlier expected table's `3 1` conflicts with that expression.

The §7.9.9 assignment probe and §7.9.10 by-value/`ref` probe pass independently in both editions. The invalid index-type and associative-to-fixed-formal probes from Slurm job 3515 are also rejected in both editions with type-compatibility diagnostics; see the preceding attempt's `RESULT.md`.

Open and closed issue searches, with candidate reviews, are in [`DEDUPE.md`](DEDUPE.md). The only isolated runtime failure is the legal unpacked-struct associative index under §7.8.5.
