# Clause 30 specify-path probe result

## Run

- Host: DAN-DESKTOP, Slurm job 3664, partition `verilog`; completed with `ExitCode=0:0`, elapsed 1 second.
- Resources: 1 CPU, 1 GiB requested, 10-minute limit.
- Source checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e` (`m7-1800-audit-c08`, dirty from the ongoing audit); only this probe and its runner were staged into the isolated run directory.
- Probe SHA-256: `ae6f086ca08d048cd79f722acf5259679447a9eaf09dce89169bf81fb700e377`.
- Compiler source SHA: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel, `/home/dsell/toolchains/iverilog-fb584a25-20261020`).
- Binary SHA-256: `iverilog` `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.
- Commands: `iverilog -B <toolchain>/lib/ivl -g2017|-g2023 [-gspecify] -o <image> p30_specify.sv`, then `vvp <image>`. Each compile and run was limited to 30 seconds.
- Raw stdout/stderr and scheduler output: [`slurm-3664-logs`](slurm-3664-logs/).

## Results

Both editions compiled and ran successfully, with and without `-gspecify`.

| Edition/mode | Output | Result |
| --- | --- | --- |
| 2017, `-gspecify` | `R1 0; R2 1; F1 1; F2 0; C1 0; C2 1; C3 1; C4 0; P1 0` | rise delay 3, fall delay 5, conditional delays 2/7 and rejection of the short pulse all match the expected values |
| 2023, `-gspecify` | Same as 2017 `-gspecify` | Same pass |
| 2017, default mode | `R1 1; R2 1; F1 0; F2 0; C1 1; C2 1; C3 0; C4 0; P1 0` | Specify delays are ignored without `-gspecify`; tool-mode observation only |
| 2023, default mode | Same as 2017 default mode | Same observation |

No diagnostic was emitted. Clause 30 behavior tested here is supported in both language editions when specify timing is enabled. This probe covers only two-delay path mapping, one state-dependent path, and default pulse rejection; it does not assess the remaining Clause 30 rules.

## Standard and dedupe

The paired standard basis is recorded in [`README.md`](README.md): §§30.4.2 and 30.5/Table 30-2 for parallel path delay mapping; §30.4.4 for state-dependent paths; and §30.7 for default pulse rejection. Open and closed issue searches and their dispositions are in [`DEDUPE.md`](DEDUPE.md). No existing issue covers these behaviors.
