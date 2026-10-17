# Matched-window Caliptra comparison against the historical 7.775 cycles/s point

**Status: Slurm job 2116 is running; results will be appended before merge.**

This matched follow-up compares the original reference build `c014c0a7975a4b0b645ea34609c802be60a10f4a` with current main snapshot `afa43b2ffa2dc1f443d25902fb0c27b655d18be0` on `cptra_ss_test_rom`. It uses the historical 100–600 mcycle window (500 cycles), three interleaved samples per build, and one pinned CPU. The historical 7.775 cycles/s result is recorded in [the original Caliptra evidence](../caliptra-top-perf-20261013/perf-summary.md).

The comparison uses the same QD-BFM (`8e34e0c6d20b6f84a5a975ba6e3de7ccd9b1dc2b`), Caliptra RTL (`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`), and adams-bridge (`b77e3d899e828d626cfc2a0d26a6b5704cc121e0`) as that historical result, with the campaign-fixed deterministic ECC source. The bounded test intentionally stops before firmware completion; runner exit 1 and `passed=false` are expected.

The Slurm runner, VPI marker, and ECC source are byte-identical to the files already preserved in the [job 2018 evidence](../caliptra-top-throughput-20261016/README.md): [runner](../caliptra-top-throughput-20261016/input/threeway/run_caliptra_top_profile.py), [VPI marker](../caliptra-top-throughput-20261016/input/threeway/mcycle-window-vpi.c), and [ECC source](../caliptra-top-throughput-20261016/input/threeway/ecc_secp384r1-deterministic.c). Their SHA-256 values are `1bfa51526b87da4e447547e5fc30a403753f6c68f369a020b0fb7897eddf602b`, `f81b51714d0f2552c666958e76cce5680191baa08b3f81c372b7f43e48e247eb`, and `c13c7c8ddf1e45b590a66b3dd64fdb01bffe7fd7c16453693435a7a28343f28d`, respectively. A rerun copies those files into the `input/` paths expected by `submit/run.sh`.

After job 2116 completes, its logs, sample outputs, hashes, and analyzer summary will be added here; the analyzer requires all six windows, firmware input hashes, and normalized simulator logs to match before reporting the speedup against both the matched c014 median and 7.775 cycles/s.
