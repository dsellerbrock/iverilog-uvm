# IEEE 1800 Clause 32 SDF IOPATH probe

The probes check whether a two-value SDF `IOPATH` replaces the matching specify-path delay and maps its values to rise and fall, and whether SDF `PATHPULSE` limits control filtering, X generation, and propagation. The `-gspecify` runs determine IEEE behavior. The additional 2023 run without `-gspecify` is a tool-mode observation because Icarus ignores specify blocks in that mode.

## Standard basis

- §32.3 requires an SDF annotator to “issue a warning” for data it cannot annotate. This SDF entry is intended to match the declared path; capture any warning or error verbatim. Printed pages 892 (2017) and 924 (2023).
- §32.4.1/Table 32-1 maps a matching SDF `IOPATH` to conditional or nonconditional specify-path delays and pulse limits. The standard’s example has SDF source/destination names matching the SystemVerilog path terminals. Printed pages 893 (2017) and 925 (2023).
- §32.8/Table 32-4 maps two SDF delay values so v1 applies to 0→1 and v2 applies to 1→0. Thus `(4) (6)` should replace the source delay of 1 with rise delay 4 and fall delay 6. Printed pages 899 (2017) and 931 (2023).
- §32.9/Syntax 32-1 gives `$sdf_annotate(sdf_file [, module_instance] [, config_file] [, log_file] [, mtm_spec] [, scale_factors] [, scale_type])`. The probe supplies the SDF path and scope. Printed pages 900 (2017) and 932 (2023).
- §32.7 covers pulse-limit annotation (2017 p.898; 2023 p.930). Explicit `PATHPULSE` values are time limits in the SDF time scale; `PATHPULSEPERCENT` is the separate percentage form. They “do not affect the delay.” With the `1ns` SDF time scale, limits `(2)` and `(3)` mean 2 ns and 3 ns. `PATHPULSE` limits above a path delay are treated as equal to that delay.
- Pulse outcomes are defined in §30.7 (2017 p.854; 2023 p.886): widths below reject 2 are rejected, widths from 2 through just below error 3 become X, and widths at least 3 propagate. The text says “pass unfiltered,” “filtered to X,” and “no pulse emerges.”

Expected with `-gspecify`, for both editions:

```text
R1 0
R2 1
F1 1
F2 0
```

These samples show rise at t14 and fall at t26, with the output still unchanged one time unit before each scheduled transition.

For `p32_pp.sv`, with `-gspecify` in both editions, the 1 ns input pulse must produce no output transition; the 2 ns pulse must produce X at about t35 and return to 0 at t37; and the 5 ns pulse must produce a clean 1 from about t57 to t62. Initial time-zero output changes are not part of those pulse observations.

Probe files: [`p32_sdf.sv`](../../../../tests/1800_audit/c32/p32_sdf.sv), [`p32.sdf`](../../../../tests/1800_audit/c32/p32.sdf), [`p32_pp.sv`](../../../../tests/1800_audit/c32/p32_pp.sv), and [`p32_pp.sdf`](../../../../tests/1800_audit/c32/p32_pp.sdf). Open+closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md); raw results and the malformed-input first attempt are in [`RESULT.md`](RESULT.md).
