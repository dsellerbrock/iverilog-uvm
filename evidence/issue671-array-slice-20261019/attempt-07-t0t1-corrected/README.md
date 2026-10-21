# Attempt 07 — corrected #671 T0/T1

Runs issue reproducer legacy + JSON editions, the required smoke set, then the graph-selected Chapter 7 queue/dynamic-array legacy and JSON focus lists. The snapshot includes the approved JSON `PASSED` stdout golden, the strengthened copy-independence reproducer, and the corrected `-g2023` registrations for the two Clause 9 tests in the shared focus list.

- Source commit: `b172f88cba48dd6b888df9cd5cbcafeb2b0856cc`, with the three overlay inputs recorded in `input/working-tree.patch` and the input SHA-256 manifest.
- Slurm job 3238 on DAN-DESKTOP; 2 CPUs / 3 GiB, 45-minute limit; fresh run root `/home/dsell/slurm-runs/iverilog-uvm/A3/issue671-slice-t0t1-20261019-07`.
