# §16.13.2 finite variable-antecedent probe

IEEE 1800-2017 and IEEE 1800-2023 §16.13.2 cover multiclocked properties. This run checks one bounded positive case: a finite ranged antecedent on `c1` followed by a consequent on `c2`. It does not cover endpoint multiplicity, local-variable capture, or termination behavior in the open issue #446.

- Host: DAN-DESKTOP, Slurm job 3581; `COMPLETED`, `ExitCode=0:0`, 1 CPU, 1 GiB, runtime 1 second.
- Source: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; pinned toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020`.
- Icarus/VVP SHA-256: `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c` / `7fa3224c44e69b555fa86c1e3e048fa2709780276c6418ff8b7a7f0d63241c02`.
- `-g2017` and `-g2023` compile and run the existing `sv_assert_multiclock_variable_antecedent` test successfully; each prints `PASSED`. Every compile and run had a 30-second timeout.
- The open-and-closed issue search for `multiclock` returned #446 only. Its acceptance criteria cover additional behavior beyond this passing finite-range case, so this result is recorded as a narrow probe and no issue was opened.
- Raw output, compiler version, checksums, source copies and the submission script are retained here. The generated `.vvp` files and remote source copies were removed after results were recorded.

The audit lead must classify whether this passing subset changes the description or status of #446. The helper currently reports its daily lead cap reached, despite the supervisor's refreshed-quota note.
