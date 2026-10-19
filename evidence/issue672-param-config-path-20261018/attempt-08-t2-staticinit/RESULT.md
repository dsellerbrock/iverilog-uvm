# #672 T2 failure reproduction

Slurm job 3153 rebuilt the committed #673 head `aabcb025ade5352adbad826fd7cff38eeddbaf26` before the static-initializer fix. The build succeeded on DAN-DESKTOP with 2 CPUs and 3 GiB; `make -j2` took 3:04.43, peak RSS 1,662,828 KiB. The built `iverilog` SHA-256 is `b2823adaf767f0e062051d62e8b042f39052e2a30e755834a8e011781a3834c8`.

The focused legacy suite ran 2 tests and failed both (`sv_generic_master_static_init`, `sv_generic_master_static_init_2023`). The focused JSON suite ran 8 failing cases, covering those two plus bare-default typedef, nested typedef, and scoped typedef-only registry static initialization in 2017 and 2023. The qualified-typedef controls also present in the run list passed. Raw output and exact test lists are in `results/`; each copied result/log checksum matches `remote-sha256.txt`.

Exit statuses: legacy 2, JSON 8. This reproduces the runtime failures first seen in T2 job 3135 and confirms the existing static-init tests are the right reproducer area. The T1 VVP focus list now covers the full ten-case static-init set, including the six additional failing cases and two passing qualified-typedef controls.

Remote build/source/install/input copies were removed only after the result files and hashes were saved. Cleanup freed 1,277,413,492 bytes; logs, results, and the job script remain on DAN-DESKTOP.
