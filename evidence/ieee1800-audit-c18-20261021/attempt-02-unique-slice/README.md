# §18 uniqueness array-slice depth probes

Five separate sources test an ascending slice (U1), the reverse range form (U2), a non-rand variable bound (U3), a slice plus scalar member (U4), and the whole-array control (U5). Each is compiled and run separately under `-g2017` and `-g2023`; each process has a 60-second timeout. See `STANDARD.md` and `DEDUPE.md`.

The lead expects U1–U5 to produce 50 successful randomizations with no duplicate members if supported. The previous job reported explicit solver refusal for slice forms and 50/50 success for whole arrays.

Slurm job 3720 uses 1 CPU, 128 MiB, and a 10-minute limit on DAN-DESKTOP. The memory request is based on the prior 40,524 KiB peak for these audit probes. Inputs are staged from branch `m7-1800-audit-c08`, HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; their SHA-256 values are in `INPUT-SHA256SUMS.txt`. Toolchain: Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`, commit `cc25756d`, with `iverilog` SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e` and `vvp` SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.

Job 3720 completed without timeout: U1–U4 each returned 0/50 in both editions, with a compile-time “not representable in the constraint solver” warning and 50 explicit runtime refusals; U5 returned 50/50 with no duplicates. See `RESULT.md` and the preserved per-case logs.
