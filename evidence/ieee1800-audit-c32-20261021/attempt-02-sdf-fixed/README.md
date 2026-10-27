# IEEE 1800 Clause 32 SDF annotation probes

The corrected probes test IOPATH annotation, two-value rise/fall mapping, and explicit PATHPULSE reject/error limits in both editions. Timing behavior is measured with `-gspecify`; the additional 2023 IOPATH run without it is a tool-mode observation because Icarus omits specify behavior in that mode.

## Standard basis and expected results

- §32.3 requires an annotator to “issue a warning” for data it cannot annotate. The listed SDF paths match the probes; capture any warning or error verbatim. IEEE 1800-2017 p.892; 2023 p.924.
- §32.4.1/Table 32-1 maps matching `IOPATH` entries to specify path delays. §32.8/Table 32-4 maps two SDF delay values: v1 to 0→1, v2 to 1→0. The `(4) (6)` IOPATH must replace source delay 1 with rise 4 and fall 6. IEEE 1800-2017 pp.893, 899; 2023 pp.925, 931.
- §32.9/Syntax 32-1 defines `$sdf_annotate(sdf_file [, module_instance] [, config_file] [, log_file] [, mtm_spec] [, scale_factors] [, scale_type])`. The probe supplies the file and scope. IEEE 1800-2017 p.900; 2023 p.932.
- §32.7 covers pulse-limit annotation (IEEE 1800-2017 p.898; 2023 p.930): explicit `PATHPULSE` values are in the SDF time scale; `PATHPULSEPERCENT` is the percentage form. These two constructs “do not affect the delay.” The 1 ns SDF scale makes `(2)` and `(3)` absolute limits of 2 ns and 3 ns.
- The pulse outcomes themselves are defined in §30.7 (IEEE 1800-2017 p.854; 2023 p.886): widths below reject 2 are rejected (“no pulse emerges”); widths at least 2 and below error 3 become x (“filtered to X”); widths at least 3 “pass unfiltered.”

Therefore, the 1 ns pulse at t10 produces no output pulse; the 2 ns pulse at t31 gives x around t35 and returns to 0 around t37; and the 5 ns pulse at t53 propagates as 1 from t57 to t62. Initial time-zero output changes do not count. `p32_sdf.sv` should print `R1 0`, `R2 1`, `F1 1`, `F2 0` with `-gspecify` in both editions.

The first attempt is preserved in the sibling [`attempt-01-sdf`](../attempt-01-sdf/RESULT.md); its SDF was unbalanced and its timing output is not a conformance result. This attempt uses balanced corrected inputs and a fresh Slurm run directory.

Probe files: [`p32_sdf.sv`](../../../../tests/1800_audit/c32/p32_sdf.sv), [`p32.sdf`](../../../../tests/1800_audit/c32/p32.sdf), [`p32_pp.sv`](../../../../tests/1800_audit/c32/p32_pp.sv), and [`p32_pp.sdf`](../../../../tests/1800_audit/c32/p32_pp.sdf). Open+closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md), and raw logs/results are in [`RESULT.md`](RESULT.md).
