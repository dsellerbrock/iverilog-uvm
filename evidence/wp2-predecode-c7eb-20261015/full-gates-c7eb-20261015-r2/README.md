# Pinned predecode full correctness gates

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.
Candidate: `4f4ec93c86ce6d767ec4639d22213ef7dc05cfc9`.
UVM core: `78c06547a2a0a29b3dc9dcafae62b75b2ff61544`.

Slurm job 1457 completed with exit code 0:0 on four CPUs and 8 GiB in
1:04:49. Both builds and installs passed, including optional FPGA target
installation. The candidate passed `make check`, the full legacy/VPI/negative
runtime gate, the JSON comparison, and UVM with real DPI.

Results:

- Legacy ivtest: 7,407 passed, 0 failed, 2 not implemented, 3 expected failures.
- VPI: 131/131; negative suite: 152/152; runtime invariants passed.
- JSON candidate: 4,662 tests, 16 failures, 0 timeouts. The pinned reference
  reran those 16 names and had the identical failure set; there were zero new
  failures. A4 confirmed the discrepancies were baseline fixture/gold issues,
  and #595 corrected them on main.
- UVM: 367 passed, 0 failed, 0 skipped, with `DPI mode: REAL DPI umbrella
  loaded`.

This qualifies the candidate on the pinned base. Final-head correctness and
the Linux/macOS/MINGW64/UCRT64/CLANG64 exact-head workflow remain pending until
the single merge-time rebase. Since this patch changes `vvp/`, the pinned-path
diff requires one deliberate new-base measurement before merge.

The run script and source provenance are in `input/`; gate logs, JSON results,
binary hashes, the job exit code, and controller state are in `results/`.
