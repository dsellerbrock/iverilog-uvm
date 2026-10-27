# §16.13.1 three-clock chain probe

IEEE 1800-2017 and IEEE 1800-2023 §16.13.1 describe concatenated multiclocked sequences; §§16.13.2–16.13.3 cover their use in multiclocked properties and clock flow. This probe checks a three-domain implication chain, two overlapping antecedents discharging at one middle-clock edge, and multi-cycle sequence segments on both sides of a second clock boundary.

- Host: DAN-DESKTOP, Slurm job 3583; `COMPLETED`, `ExitCode=0:0`, 1 CPU, 1 GiB, runtime 1 second.
- Source: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; pinned toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020`.
- Icarus/VVP SHA-256: `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c` / `7fa3224c44e69b555fa86c1e3e048fa2709780276c6418ff8b7a7f0d63241c02`.
- `-g2017` and `-g2023` compile and run `sv_assert_multiclock_chain3.v`; each emits `PASSED`. Compile and run commands each had a 30-second timeout.
- This broadens the passing evidence for the existing open issue #446 but does not exercise `matched`, sequence local-variable capture, or termination semantics. No new issue was opened.
- Raw logs, toolchain/source checksums, compiler version, and run script are retained alongside this result. Generated `.vvp` files and remote source copies were removed after verification.

The audit lead still needs to classify the tested subsets and decide whether #446's issue text should be updated. The lead helper reports its daily cap reached despite the refreshed-quota note.
