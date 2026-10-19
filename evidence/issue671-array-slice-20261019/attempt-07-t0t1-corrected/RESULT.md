# Attempt 07 — corrected #671 T0/T1

- Host/job: DAN-DESKTOP, Slurm job 3238; 2 CPUs, 3 GiB, 45-minute limit.
- Source snapshot: commit `b172f88cba48dd6b888df9cd5cbcafeb2b0856cc` plus `input/working-tree.patch` and the approved JSON stdout golden embedded in `input/source.tar.gz`. The snapshot contains the strengthened copy-independence reproducer and the two corrected `-g2023` registrations.
- Toolchain SHA-256: `iverilog` `550a0a5e6eb9e1a194d1db61b527876fb1fc5794136f1c8f034e82db745a8a0f`; `vvp` `9cec7d4b048020d06a99ca73e4a4e539e77be8dc4cf863bacc7bfc1dcfb82c58`.
- Build: `autoconf.sh`, configure with `--enable-libveriuser`, `make -j2`, `make install`; build wall time 2:59.14 and maximum RSS 1,662,756 KiB.
- T0 issue reproducer: legacy 2/2 and JSON 2/2 passed. Smoke: legacy 56/56, VPI 133/133, indexed dynamic-array slice 16/16, and all remaining smoke scripts passed.
- T1 Chapter 7 queue/dynamic-array focus: legacy 91/91 and JSON 84/84 passed. The corrected Clause 9 entries use `-g2023`, matching their canonical registrations.
- Raw log archive SHA-256: `ad1a70a2ec11885bfd5008e375cd3bddaef83e906078d4185849d43c695b25d3` (`raw-slurm-3238/results-3238.tar.gz`). Every archived log/result file matches `raw-slurm-3238/remote-sha256-results.txt`.
- The job is no longer in `squeue`; `scontrol` cannot query completed job 3238 and Slurm accounting is disabled, so the scheduler's exact `ExitCode` and total elapsed time are unavailable. All captured build, issue, smoke, and T1 logs report success. Build peak RSS and wall time above come from `/usr/bin/time -v`.
- After checksum verification, removed the exact Slurm run tree; DAN-DESKTOP reported 917,894,899 file bytes freed (about 0.85 GiB).
