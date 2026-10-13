# Original start run 584: wrapper-path audit

Job 584 built and installed Icarus from source commit `198f0abec3154a916d13730cee24549e24e076b0`; the recorded compiler and VVP hashes are in `source-build-environment.txt`. Its environment log proves the installed binaries were Icarus 13, but it does not prove that the suite used them.

The suite did not use the installed build. `run.sh` created wrappers under the run directory's `tool-bin/`. The copied runner set `OUT_DIR` to `evidence/current-main/out`, while `runner-safe` prepended `OUT_DIR/runners/bin/` and the Python launcher put `evidence/current-main/tool-bin/` on `PATH`. Neither path contained the wrappers. Reconstructing that exact `PATH` selects `/usr/bin/iverilog`, SHA-256 `a6681e0b577dcfc4ea83d1591a5714710b0b3535ebb36491ee8177553bab9631`, version 12.0.

The retained 1,027 logs and 603/1,027 summary document that failed launch configuration; they are not valid Icarus 13 baseline evidence. A corrected replay must place wrappers where the runner actually resolves them and assert both paths before running tests.
