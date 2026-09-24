# CSRNG time-zero scheduler candidate (2026-09-23)

`result.json` and the linked raw logs record the exact compiler and release replay. The faithful packed-tri feedback reducer now reaches time one in both IEEE editions. The unchanged released CSRNG smoke advances to UVM and fails at `cfg.randomize()` on a distinct joint-distribution restriction. Process exit zero, the reported `TEST FAILED CHECKS`, and EndOfSimulation assertion errors do not constitute a DV pass. The earlier vec8-filter false green remains invalidated in `../opentitan-dist-vec8-followon-20260923/result.json`.
