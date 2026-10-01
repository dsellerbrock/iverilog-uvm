# Caliptra single-core compiler assessment — 2026-09-28

The selected 52-case DV campaign remained stopped. All performance changes below were made only in disposable source or VVP images; no pinned RTL or production compiler code was changed.

## Fixed-loop specialization

The Adams Bridge adder hierarchy accounts for 434,035 of 636,346 sampled instructions (68.2%) in a frozen 200-edge Caliptra window. Disposable expansion of its fixed 46-, 2-, and 4-iteration loops preserved stdout, execution, port, and bus trace hashes in two opposite-order, bounded 240-edge full-top pairs. Steady CPU time over edges 40–240 was 18.622 to 15.100 seconds and 18.183 to 15.211 seconds: 17.6% less CPU using the medians. A four-pair 1,000-cycle A2B reducer improved from a 3.304-second median to 1.403 seconds (2.355×), with the same output hash. The full-top image grew 1.63%; one compile pair rose from 11.661 to 12.075 seconds.

This is an upper bound for a future compiler transform. Source expansion removes the VPI-visible loop index, so it cannot be used as a production workaround. A correct compiler pass would need bounded procedural-body cloning and constant folding; four-state index and arithmetic behavior; visible index stores and fallback if the live index changes; and unchanged event, callback, and nonblocking-assignment order. The current VVP target emits `NetForLoop` directly (`tgt-vvp/vvp_proc_loops.c`). Its synthesis unroller does not preserve these simulation effects.

## Smaller techniques

An exact disposable VVP peephole replaced 320 loop increment sequences with the existing `%addi` opcode. Four alternating A2B reducer pairs preserved output but had CPU ratios of 1.039, 1.002, 1.018, and 0.983 (median 1.010), including one regression. Earlier affine-index reducers were neutral/slower, and fused NBA-offset codegen gave a 1.009 median CPU ratio in three bounded full-top pairs. Same-width vector reuse was slightly slower in its bounded full-top pair. A native VVP `-O3` build gave mixed results across three bounded pairs. No small speedup patch is justified by these measurements.

Keep the `-O2` build and defer performance work while addressing the DV blocker. If performance becomes the priority, scope fixed-loop specialization as a separate compiler feature with focused 2017/2023 four-state, VPI, timing, and NBA controls before a full-top test.
