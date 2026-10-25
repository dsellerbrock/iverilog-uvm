# §16.13.2 multiclock multiplicity probe

IEEE 1800-2017 and IEEE 1800-2023 §§16.13.2–16.13.3 cover multiclocked properties and clock flow. This probe checks that overlapping antecedent matches remain distinct across a clock-domain handoff and through fixed and bounded consequent stages.

- Host: DAN-DESKTOP, Slurm job 3582; `COMPLETED`, `ExitCode=0:0`, 1 CPU, 1 GiB, runtime 0 seconds.
- Source: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; pinned toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020`.
- Icarus/VVP SHA-256: `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c` / `7fa3224c44e69b555fa86c1e3e048fa2709780276c6418ff8b7a7f0d63241c02`.
- `-g2017` and `-g2023` compile and run `sv_assert_multiclock_multiplicity.v`; each emits `PASSED`. The check verifies three separate verdicts at the first destination edge, three fixed-chain verdicts, three bounded-window verdicts, and vacuous pass actions. Compile and run commands each had a 30-second timeout.
- The open-and-closed issue search for `multiclock` returned #446 only. This positive case narrows the evidence for that open issue; it does not cover local-variable capture or endpoint synchronization via `matched`, so no issue was opened.
- Raw logs, toolchain/source checksums, compiler version, and run script are retained alongside this result. Generated `.vvp` files and remote source copies were removed after verification.

The audit lead's classification remains pending: the helper still reports its daily lead cap reached, contrary to the refreshed-quota note.
