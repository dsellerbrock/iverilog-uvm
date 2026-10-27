# §20.14 coverage system functions — 2026-10-20

IEEE 1800-2017 §20.14 and 1800-2023 §20.13 list `$coverage_control`, `$coverage_get_max`, `$coverage_get`, and the functional-coverage `$get_coverage()`. The exact argument forms, unavailable-coverage results, and constants are recorded in [STANDARD.md](STANDARD.md). This probe checks unavailable toggle/code coverage and one functional covergroup with two bins and one hit.

## Run

- Slurm job 3547 on DAN-DESKTOP, compiler cc25756d1; 1 CPU, 1 GiB, 10-minute limit; submitted and started at 2026-10-20 13:11:12 UTC, completed at 13:11:13 UTC, exit 0, elapsed 1 second.
- Compiled and ran `p20_14_cov.sv` under both `-g2017` and `-g2023`, pinned with `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl`; each process had a 30-second timeout.
- Compiler SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA-256: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`; probe SHA-256: `7806e4f93ede0ea74c8bea87fbbb50b0ca6e42e7afb8319d8fed86213b9f4539`.
- Raw source, compile/runtime output, warnings, run script, and Slurm job record are in [remote-3547](remote-3547/) and [slurm-job-3547.txt](slurm-job-3547.txt). The remote run directory was 22,839 bytes before cleanup. Slurm accounting is disabled; `sstat` had no completed job step, so peak RSS is unavailable.

## Results

Both editions compiled and ran successfully. Runtime output in each was:

```text
R1 0
R2 0
R3 0
GC 50.00
```

The three warnings explicitly say each code-coverage function returns `SV_COV_NOCOV` because code coverage is not instrumented. These values match the §40.3.2.1–§40.3.2.3 rules for unavailable toggle coverage. The covergroup result matches §19.9: one of its two bins was sampled, giving 50.00 overall functional coverage.

## Issue dedupe

Before probing, open and closed issue searches were saved for `$coverage_control`, `$coverage_get`, `$get_coverage`, `SV_COV`, and `20.14`. No issue duplicates these system-function results. Closed #7 and #19 are broad, older functional-coverage umbrellas. Open #622 covers `get_inst_coverage(ref int, ref int)` bin-count outputs; open #627 covers static covergroup/coverpoint `get_coverage()` methods. Open #688 is specifically `$set_coverage_db_name` and `$load_coverage_db`, which this probe excludes. Search JSON and inspected issue bodies are in this directory.

## Audit scope

`$coverage_merge` and `$coverage_save` were not tested here. The database persistence functions from §19.9 remain tracked separately in #688. No new issue was filed from this probe.
