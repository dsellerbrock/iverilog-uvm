# Clause 40.5 VPI coverage results

Slurm job 3682 completed on DAN-DESKTOP on 2026-10-21; `scontrol` reports `COMPLETED`, exit `0:0`, one CPU, 1 GiB requested, and a five-minute limit. Scheduler start/end timestamps were both 02:45:37 MDT (runtime rounded to 0 seconds); Slurm accounting is disabled, so peak RSS is unavailable. The exact batch and per-command logs are in [`raw-slurm-3682/`](raw-slurm-3682/).

Pinned Icarus source commit: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (13.0-devel). The VPI module compiled successfully, and `p40.sv` compiled and ran with exit 0 under both `-g2017` and `-g2023`.

Both editions printed:

```text
coverage_check=0
coverage_check_error_level=0
toggle_coverage=-1
toggle_coverage_error_level=0
coverage_start=0
coverage_start_error_level=0
```

Both editions also wrote these runtime diagnostics to stderr:

```text
Unsupported VPI control operation 753.
Unsupported VPI control operation 750.
```

Thus the two control calls returned numeric 0 (the standard's `SV_COV_NOCOV` value for unavailable coverage on check/start), but Icarus explicitly reported both operations as unsupported; `vpi_chk_error` reported level 0 for each call. `vpi_get(vpiToggleCoverage, module)` returned -1 rather than a nonnegative covered-item count. The lead must classify whether these runtime observations are distinct conformance gaps, given the standard's §40.5 VPI wording and the already-filed Annex K header issue #885.

Direct standard extracts, exact issue searches, and source/hash metadata are linked from [`README.md`](README.md), [`DEDUPE.md`](DEDUPE.md), and the raw log directory.
