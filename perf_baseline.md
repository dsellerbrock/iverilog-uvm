# perf-event-loop branch — P1 baseline

Captured 2026-05-08 from branch base `a18d2112a` (development tip immediately
after `scripts/install_ivl.sh` and `type_of_t` for `type(T)===`).

## Canonical regression (`tests/*.sv`)
```
PASS    : 66
UNCLEAR : 30  (UVM tests that don't print 'PASS' string but exit clean — likely working)
TIMEOUT :  5  (configdb_*, vif_config_db_test)
SIM_FAIL:  3  (assert_fail_test, dpi_basic_test, dpi_real_test)
COMPILE :  2  (vif_smoke, vif_smoke_v2)
Total   : 106
Wall-clock: 98 s (24 jobs not used; sequential)
```

## sv-tests
```
PASS   : 999
FAIL   :   5    (3 chapter-8 should-fail interface-class, 2 chapter-11 streaming)
TIMEOUT:  23    (all chapter-16 SVA UVM, hung in uvm_phase_hopper.run_phases)
ERROR  :   0
Total  : 1027   (97.3 % PASS)
```

## OT smoke vseq SIGUSR1 hot-symbol histogram
30 samples × 10 s, total 300 s wall-clock (~10 µs sim time per sample interval).
Every sample's call stack ended in `vthread_run` ← `schedule_simulate` (the
main scheduler loop) — the histogram below counts the *frame inside* that.

```
30/30  vthread_run / schedule_simulate (scheduler driver — every sample)
13/30  construct_scope_fullname (recursive)        ← BIGGEST WIN AVAILABLE
12/30    └─ called via scope_get_str(vpiFullName)
 5/30  simple_set_rbuf_str
 2/30  vthread_mark_scheduled / schedule_vthread / of_DELAYX
 1/30  of_LOAD_VEC4 / of_NORR / of_CVT_VR / __do_dyncast / others
```

`construct_scope_fullname` is in `vvp/vpi_scope.cc:168`. It recursively
walks the scope tree from leaf to root and uses `strcat` at each level,
giving each call cost O(D × L) for depth D and total path length L.
UVM calls `get_full_name()` constantly (every `uvm_info`, every component
lookup, every config_db read).  Scope hierarchies don't change after
elaboration — the result can be cached on `__vpiScope` and reused.

## What "improvement" means on this branch
A commit must show measurable improvement on at least one of:
- smoke sim/wallclock advance rate at 5-min mark.
- canonical regression wall-clock under 90 s.
- sv-tests wall-clock at TIMEOUT=10 (currently ~3.5 min in non-parallel mode).

## Non-goals (do not implement on this branch)
- JIT bytecode compiler.
- Lock-free scheduler.
- Multi-threaded simulation.
- Any feature work that doesn't show up in the histogram.
