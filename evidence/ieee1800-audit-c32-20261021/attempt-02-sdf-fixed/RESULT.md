# Clause 32 corrected SDF probe results

## Run

- Host: DAN-DESKTOP, Slurm job 3667, partition `verilog`; completed with `ExitCode=0:0`, elapsed 1 second.
- Resources: 1 CPU, 1 GiB requested, 10-minute limit.
- Source checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e` (`m7-1800-audit-c08`, dirty from the ongoing audit); only the four Clause 32 probe files and runner were staged.
- Compiler source SHA: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel, `/home/dsell/toolchains/iverilog-fb584a25-20261020`).
- Probe SHA-256: `p32_sdf.sv` `e311f556c605d4850607070fc39e9d675255d003a443a760948c7b725a7a8931`; `p32.sdf` `3a8ccda3a734a415aeb575fcdc364c8ff3f4f4b689619429edf271a08dc184b4`; `p32_pp.sv` `c56b200eb6406084572ad262524ed45724d502366048830714092fb4b490ba3c`; `p32_pp.sdf` `fa6ac086c5d5da9eea19ae2a58b51035a705a81e2642cb6eb2189de980d60984`.
- Binary SHA-256: `iverilog` `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.
- Commands: `iverilog -B <toolchain>/lib/ivl -g2017|-g2023 -gspecify -o <image> <test>.sv`, then `vvp <image>`. A 2023 IOPATH run omitted `-gspecify` for a mode note. Each compile and run had a 30-second limit.
- Raw stdout/stderr, per-log SDF error counts, and scheduler output: [`slurm-3667-logs`](slurm-3667-logs/).

## Results

All five compile/run cases completed with exit code 0. The run script executed `grep -c "SDF ERROR"` on every log; every count was zero.

**IOPATH**, both editions with `-gspecify`, printed:

```text
R1 0
R2 1
F1 1
F2 0
```

The SDF rise delay 4 and fall delay 6 replace the source delay of 1 in both editions. No warning or error was emitted for either matching annotation.

**PATHPULSE**, both editions with `-gspecify`, printed:

```text
Y 1 0
Y 57 1
Y 62 0
p32_pp.sv:13: $finish called at 78 (1ns)
```

The width-1 pulse produced no output pulse, as expected below reject 2. The width-2 pulse at t31 was fully rejected: there was no X transition around t35 and no return-to-0 transition around t37. The width-5 pulse propagated at t57–t62. With explicit reject 2/error 3 limits, the missing X pulse differs from the §30.7 requirement; the audit lead will classify whether this is the §32.7 annotation gap or a boundary-handling gap.

The 2023 run without `-gspecify` produced `R1 1`, `R2 1`, `F1 0`, `F2 0`. Its compile warning was exactly `p32_sdf.sv:8: warning: Omitting $sdf_annotate() since specify blocks and interconnects are being omitted.` This is only the command-line mode observation, not an annotation warning for an unmatchable SDF item.


## Audit-lead classification

The lead classifies §§32.4.1, 32.8, and 32.9 as IMPLEMENTED (tested subset), with `-gspecify`, in both editions. §32.7 is PARTIAL: the explicit PATHPULSE limits are not applied, and there is no §32.3 warning when the values are silently skipped. The lead filed [#880](https://github.com/dsellerbrock/iverilog-uvm/issues/880) for that gap. Total audit issues: 143 (previously 142).

The first malformed-input run (job 3666) is kept separately in [`attempt-01-sdf`](../attempt-01-sdf/RESULT.md) and is not used as conformance evidence. Direct standard citations, time calculations, and open/closed issue dedupe are in [`README.md`](README.md) and [`DEDUPE.md`](DEDUPE.md).
