# Clause 31 timing-check probe result

## Run

- Host: DAN-DESKTOP, Slurm job 3665, partition `verilog`; completed with `ExitCode=0:0`, elapsed 1 second.
- Resources: 1 CPU, 1 GiB requested, 10-minute limit.
- Source checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e` (`m7-1800-audit-c08`, dirty from the ongoing audit); only this probe and its runner were staged into the isolated run directory.
- Probe SHA-256: `2210c30b618cb2d1d8fb3fd92b042fe0d91e980ce1d24e9950883af88d8d983a`.
- Compiler source SHA: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel, `/home/dsell/toolchains/iverilog-fb584a25-20261020`).
- Binary SHA-256: `iverilog` `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.
- Commands: `iverilog -B <toolchain>/lib/ivl -g2017|-g2023 [-gspecify] -o <image> p31_tchk.sv`, then `vvp <image>`. Each compile and run was limited to 30 seconds.
- Raw stdout/stderr and scheduler output: [`slurm-3665-logs`](slurm-3665-logs/).

## Results

All four edition/mode combinations compiled and ran with exit code 0.

With `-gspecify`, both editions produced the three expected reports on stdout:

```text
p31_tchk.sv:5: Timing violation: $setup check in p31_tchk.u at time 10
p31_tchk.sv:6: Timing violation: $hold check in p31_tchk.u at time 11
p31_tchk.sv:7: Timing violation: $width check in p31_tchk.u at time 22
N 3 1
```

Both editions produced empty stderr. The reports occur at the expected times; notifier starts at 0 and changes 0→1→0→1, so `N 3 1` confirms three changes. The setup, hold, and width windows match the direct IEEE arithmetic recorded in [`README.md`](README.md).

Without `-gspecify`, both editions output `N 0 0` and produced no stderr. This is an Icarus command-line mode observation only: IEEE timing behavior was tested with `-gspecify`.

## Standard and dedupe

The direct 2017/2023 standard citations and both-edition page numbers are in [`README.md`](README.md). Open and closed issue searches and their dispositions are in [`DEDUPE.md`](DEDUPE.md). No existing issue covers these behaviors.
