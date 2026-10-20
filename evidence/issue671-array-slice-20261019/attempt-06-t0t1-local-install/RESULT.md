# Attempt 06 — Slurm T0/T1 with corrected install prefix

- Source commit: `b172f88cba48dd6b888df9cd5cbcafeb2b0856cc`, with reproducer edits recorded in `input/working-tree.patch` and the approved JSON stdout golden in the source snapshot.
- Host: DAN-DESKTOP; Slurm job 3229, 2 CPUs / 3 GiB.
- Build and install passed. Installed `iverilog` SHA-256: `23b852da3bad476dc40fb9f1ccda5c58ff9594423a05406037c40d874a1f7c01`; `vvp`: `962ec5fcccaf824565a91d86f05b03a4808ca4668f53da489daca8c7eab3ae90`.
- T0 issue regressions passed: legacy 2/2 and JSON/VVP 2/2. The stdout golden matched `PASSED` in both JSON editions.
- T0 smoke passed: legacy 56/56, VPI tests 133/133, and all additional smoke scripts completed successfully.
- T1 legacy focus reported 89/91. The two failures were not simulator regressions: both list entries compiled `ref static` tests with `-g2012`; the canonical `regress-sv.list` registrations and JSON fixture select `-g2023`. Their exact compiler diagnostics are preserved in `t1-failure-logs/`.
- T1 JSON did not run because the legacy runner stops on its first failed selection. The focus-list language-mode entries were corrected to `-g2023`; rerun the full T0/T1 gate on that corrected source snapshot.
- All transferred result and log files match the remote SHA-256 manifest in `raw-slurm-3229/remote-sha256-results.txt`.
- After recording this result and preserving the manifest-verified local logs, removed the exact remote run tree `/home/dsell/slurm-runs/iverilog-uvm/A3/issue671-slice-t0t1-20261019-06`; DAN-DESKTOP reported 926,669,110 bytes freed (about 0.86 GiB).
