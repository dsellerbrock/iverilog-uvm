# Matched-window Caliptra remeasurement on main `9b5fad2`

This is the one required remeasurement after main advanced from `afa43b2` to
`9b5fad2` with VVP runtime changes. It compares the historical reference build
`c014c0a7975a4b0b645ea34609c802be60a10f4a` against the new main head on
`cptra_ss_test_rom`. The earlier `afa43b2` measurement remains preserved in
[the previous matched run](../caliptra-775-matched-20261017/README.md).

Slurm job 2189 completed with exit code 0 on DAN-DESKTOP. Measurement pin:
current main `9b5fad2afb4104caa816b257d5bccc40f01b8c66`; matched baseline:
`c014c0a7975a4b0b645ea34609c802be60a10f4a`. The run used a fixed 100–600
mcycle window (500 cycles), three interleaved samples per build, and one pinned
CPU. The Slurm job reserved four CPUs for the builds and 8 GiB; each simulator
run was pinned to one CPU.

| Build | Samples (cycles/s) | Median | Spread |
|---|---:|---:|---:|
| c014 baseline | 8.121, 8.206, 8.159 | 8.159 | 1.05% |
| main `9b5fad2` | 10.670, 10.608, 10.188 | 10.608 | 4.54% |

The new main head is **+30.00%** against the same-job c014 median and **+36.43%**
against the historical 7.775 cycles/s point. The historical reference and
external inputs are described in [the original Caliptra evidence](../caliptra-top-perf-20261013/perf-summary.md).
QD-BFM (`8e34e0c6d20b6f84a5a975ba6e3de7ccd9b1dc2b`), Caliptra RTL
(`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`), adams-bridge
(`b77e3d899e828d626cfc2a0d26a6b5704cc121e0`), and deterministic ECC source
remained fixed. All six firmware input manifests and normalized logs matched.

The bounded test stops before firmware completion; runner exit 1 and
`passed=false` are expected. Raw sample logs, manifests, hashes, build logs,
and analyzer output are preserved in `runs/`, `logs/`, and `results/`. The job
script is `submit/run.sh`; the runner and VPI marker are in `input/`. The
deterministic ECC source is gzip-compressed byte-for-byte in
`input/ecc_secp384r1-deterministic.c.gz`; its hash is in
`results/input-sha256.txt`.
