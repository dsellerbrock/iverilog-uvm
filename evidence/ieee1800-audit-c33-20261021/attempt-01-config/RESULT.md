# Clause 33 configuration probe results

## Configuration probe: Slurm job 3668

- Host: DAN-DESKTOP, partition `verilog`; `scontrol` reported `COMPLETED`, exit `0:0`, 1 second, 1 CPU and 1 GiB requested.
- Probe checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e` (`m7-1800-audit-c08`, dirty audit branch).
- Pinned toolchain source SHA: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; Icarus 13.0-devel. Tool and runtime hashes are in [`slurm-3668-logs/a3-c33-config-3668.out`](slurm-3668-logs/a3-c33-config-3668.out).
- Probe SHA-256: `p33_cfg.sv` `f695211a086f151fbf7ab1cd43b03c5a0a18709e008d05d581f71e491e126d1f`.
- Commands: `iverilog -B <toolchain>/lib/ivl -g2017|-g2023 -s cfg|top -o <image> p33_cfg.sv`; successful compiles would run with `vvp <image>`. Each compile/run had a 30-second timeout.
- Raw output: [`slurm-3668-logs`](slurm-3668-logs/).

All four attempts (`-g2017`/`-g2023`, `-s cfg`/`-s top`) failed at line 1 with:

```text
p33_cfg.sv:1: sorry: config declarations (library-based cell binding) are not supported; remove the config block or select the implementation with plain module names.
```

No executable was produced. Because even the `-s top` build rejects a source file containing the config declaration, this does not isolate normal root selection. The separate modules-only control below does.

## Modules-only root-selection control: Slurm job 3669

- Host: DAN-DESKTOP, partition `verilog`; `scontrol` reported `COMPLETED`, exit `0:0`, 1 second, 1 CPU and 1 GiB requested.
- Same pinned toolchain source SHA and checkout as job 3668.
- Control SHA-256: `p33_cfg_control.sv` `f5d97e2e871ebd8edbdee461ef23c304674a54d5f951fd8764ce2c9bf85a151a`.
- Commands: `iverilog -B <toolchain>/lib/ivl -g2017|-g2023 -s top -o <image> p33_cfg_control.sv`, then `vvp <image>`. Each process had a 30-second timeout.
- Both editions compiled and ran successfully, printing exactly `LEAF`; raw logs are in [`slurm-3669-logs`](slurm-3669-logs/).

The pinned compiler's `iverilog -h` lists `-s topmodule` as its root-selection option. The host man page also documents module root selection but is Icarus 12.0, so it is not used as version-specific evidence. No configuration-specific command-line selection method is documented in the pinned compiler help.

## Standard and issue disposition

IEEE 1800-2017/2023 §33.4.1 (Syntax 33-4) defines config declarations; §33.4.1.1 the design statement; §33.4.1.3 instance selection; §33.4.1.5 `liblist`; and §33.4.1.6 `use` binding. The probe exercises `design work.top`, `default liblist work`, and `instance top.u use work.alt`; selected config behavior should replace `leaf` with `alt` and print `ALT`. The standard leaves command-line config selection to tools.

Open+closed dedupe terms were `config`, `configuration`, `liblist`, and `33.`. The pre-file results are recorded in [`DEDUPE.md`](DEDUPE.md); the refreshed post-file searches show only the newly opened #881 as a Clause 33 match. Tech lead filed [#881](https://github.com/dsellerbrock/iverilog-uvm/issues/881) as UNSUPPORTED. Probe/checkout provenance corrections on #876–#881 are recorded in [`PROVENANCE-CORRECTIONS.md`](PROVENANCE-CORRECTIONS.md).
