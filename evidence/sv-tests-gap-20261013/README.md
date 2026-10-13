# sv-tests gap baseline evidence — 2026-10-13

- Slurm job: 792 on DAN-DESKTOP.
- Icarus source: `a15ae5be50b3b782c2590711cc4861a01ef11f6c`.
- Icarus binary SHA-256: `b0b618fd7982b520347be3f78154fd5c146a92e72952b30659661a1ff911d1bd`.
- VVP binary SHA-256: `1c4b71141901e58589cfba21fb8afb37a7a3e378eccc4711fbeb075a5e124579`.
- sv-tests: `c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7`.
- sv-tests archive SHA-256: `3924ac0ef31a1cd3d39bb6942b4b313b690468f9ae296210f6e9e3093b640ac5`.
- Failing-log archive SHA-256: `cbb04eca4458fb03b9430160ce88be23e45aa76e53f5089af1f396a903151960`.
- UVM: `656f20d087370a7c742e00188d20bbf30fa95339`.
- Environment: Ubuntu on DAN-DESKTOP, GCC 15.2.0, Python 3.14.4.
- Result: 1,027 applicable, 603 pass, 424 nonpassing; the runner emitted
  `SVTESTS_END_PASS` after completing all 1,027 cases.

`run.sbatch`, `run_icarus_svtests.py`, `runner-safe`, `environment.txt`,
`summary.json`, corpus provenance, and archive checksum preserve the command
and exact tool/input provenance. `raw-failing-logs.tar.gz` contains the 424
nonpassing case logs under `raw-failing-logs/Icarus/`; its embedded
`SHA256SUMS` lists every log. Extract it in this directory to resolve the
`raw_log` values in [`../../docs/conformance/sv_tests_gap_2026-10-13.csv`](../../docs/conformance/sv_tests_gap_2026-10-13.csv).

The temporary Slurm run directory is not the evidence source of record.
