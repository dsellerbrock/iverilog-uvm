# §20.8–§20.9 split isolation probe

Date: 2026-10-20. Host: `MacBook-Air.local`, Darwin 27.0.0, arm64.

This isolates each `ck()` expression from `tests/1800_audit/c20/p20_08a_math_bits.sv`, retaining its declarations and header, and runs the 17 checks plus a header-only control in both language editions. The original generator assertion expected 16 calls, but the source contains 17 because `clog2_wide` and `clog2_const` share a line. The source count was corrected; initial setup-count mistakes are preserved in `setup-count-mismatch*.log` and are not simulator results.

Command: `python3 evidence/ieee1800-audit-c20d-20261019/attempt-03-split/generate_checks.py`, then `evidence/ieee1800-audit-c20d-20261019/attempt-03-split/run-probes.sh`. The script applies `~/codex-supervisor/localrun 10` independently to each compile and run, sequentially, for `-g2017` and `-g2023`.

Toolchain: `/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog` SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; `vvp` SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

Results: all 36 compiles succeeded. In each edition, 16 isolated checks returned `RESULT pass=1 fail=0`; the header control returned `RESULT pass=0 fail=0`. Only `s_var_ctl` failed at runtime, exit 134 in both editions:

```
internal error: vpi_get_value(<format=5>) not implemented for __vpiVThrVec4Stack.
Assertion failed: (0), function vpi_get_value, file vpi_vthr_vector.cc, line 589.
```

The failing check is `$countbits(v8, ctl[0], ctl[1])` after assigning `ctl[0]=1'bx; ctl[1]=1'bz;`; expected count is 2. The combined probe's abort is therefore isolated to variable X/Z control arguments. Full output is in `summary.log`; each compile/run has an individual log. The 72 localrun records sum to 1.69 seconds of process real time; peak recorded RSS was 6,619,136 bytes.
