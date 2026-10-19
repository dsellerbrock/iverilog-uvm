# #419 focused T0/T1 — Slurm job 2796

- Host: DAN-DESKTOP, Linux x86_64 (WSL2); Icarus Verilog 13.0 devel.
- Source: HEAD `8caff6bf021ad16ed81f3940735549ed0618d592` plus the dirty tree recorded in `source-dirty.txt`; staged source archive SHA-256 `56d771543d5ffa8cdaa225d486546a58fcfd4f68c6c36710e7409d489639f93e` (matches the remote archive).
- Build/run: the exact `run.sbatch` script; configure, `make -j2`, install, T0 and T1 all exited 0. Slurm reports COMPLETED, `ExitCode=0:0`, wall time 00:07:38, 2 CPUs, 4 GiB requested. MaxRSS was not retained by this Slurm setup.
- Compiler binary SHA-256: `iverilog` `241dc92080935603f4a991b149eebda4f9fe7ad2e4b783784c661b246af031a2`; `vvp` `af1ccaaf9407a29b9f4f950f625f6d90454d46292bae1a7a0c4689cac55c363c`.
- T0: six issue tests passed in legacy and JSON runners; `ci/run-smoke.sh` passed.
- T1: 15 selected neighboring tests passed in legacy and JSON runners. Selection is recorded in `run.sbatch` and the generated `t1-*.list` files.
- Final gate marker: `GATE_RESULT=PASS`; `script.exit` is 0. T0/T1 outputs and the Slurm scheduler log are included in `results/`.

This is the final passing evidence for the current feature snapshot. A temporary extra `rand_mode` assertion was tried in attempt-07, but its procedural indexed-struct-member accesses are unsupported by the current compiler; that assertion was removed. The current paired regression source matches the source in this passing attempt, and no compiler or runner changes followed this run.
