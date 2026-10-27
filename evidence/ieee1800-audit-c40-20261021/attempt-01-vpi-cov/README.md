# Clause 40.5 VPI code-coverage probe

`tests/1800_audit/c40/p40.sv` loads `vpi_cov.c` as a VPI module. The probe calls `vpi_control(vpiCoverageCheck, vpiToggleCoverage, p40)`, queries `vpi_get(vpiToggleCoverage, p40)`, then calls `vpi_control(vpiCoverageStart, vpiToggleCoverage, p40)`. It checks and prints VPI error information after each operation. No code-coverage instrumentation is available in this simulator, so this probes the standard's unavailable-coverage behavior.

The local public `vpi_user.h` does not name these Annex K constants. The probe therefore has guarded fallbacks from IEEE 1800-2017/2023 Annex K: `vpiCoverageStart=750`, `vpiCoverageCheck=753`, and `vpiToggleCoverage=763`. The fallback values are used only when the installed header does not define the names.

## Standard basis

- IEEE 1800-2017 §40.5.3–§40.5.4, pp. 1130–1133: `vpi_get(<coverageType>, instance_handle)` returns the number of covered items; coverage control is through `vpi_control(<coverageControl>, <coverageType>, instance_handle)`, and its semantics are per `$coverage_control()` in §40.3.2.1.
- IEEE 1800-2023 §40.5.2–§40.5.3, pp. 1166–1169: the same property and control requirements.
- IEEE 1800-2017/2023 §40.3.2.1 / Table 40-1 (pp. 1121/1156): `SV_COV_NOCOV` is the specified result for both check and start when no coverage is available. The paired Clause 20 system-function probe in job 3547 confirmed Icarus's unavailable-coverage result.

The §40.5.2/§40.5.3 property description says `vpi_get` returns the number of covered items. This probe records that result for unavailable toggle coverage; the standard's explicit `SV_COV_NOCOV` result applies to the check/start control operations through §40.3.2.1.

## Inputs and run

`input/` contains byte-for-byte copies of the two probe sources. `run.sbatch` builds the VPI module and runs the SV design with `-g2017` and `-g2023`, using one CPU, 1 GiB, and a five-minute Slurm limit. Each build/compile/run subprocess has a wall-clock timeout.

The pinned compiler is `/home/dsell/toolchains/iverilog-fb584a25-20261020` (source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, Icarus 13.0-devel). The batch output records executable and input hashes, stdout/stderr, and exit statuses.
