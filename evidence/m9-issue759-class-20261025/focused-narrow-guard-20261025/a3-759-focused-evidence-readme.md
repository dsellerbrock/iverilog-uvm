# M9 #759 narrowed class-handle assignment check

Host: macOS local runner. Compiler: Icarus Verilog 13.0 (devel), freshly installed from this worktree; binary mtime 2026-10-25 14:45:13. Build: `make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex && make install` under `macslot localrun 1800`.

Focused check: `.github/ivtest_focus_gate.sh` ran serially through the legacy and JSON runners using the local-install compiler. Result: 14/14 legacy and 14/14 JSON/VVP passed; elapsed 2.17 s, peak RSS 21,790,720 bytes. The CE set covers direct assignment, initializer, selected class property, compound assignment, output clockvar, and a concrete generic-class specialization, each in IEEE 2017/2023. The paired generic `new` positive test passed and ran with `PASS` in both editions.

The 2023 legacy wrappers now include the fixture via `ivtest/<file>.v`; this avoids a false-positive CE caused by unresolved relative includes. The per-test stderr checks in `a3-759-ce-diagnostic-counts.txt` show one §6.22.5 diagnostic for each compile-error JSON row and no missing-include errors.

Probes after the guard: the concrete `box#(payload)` specialization rejects `q = item` with one §6.22.5 diagnostic in both editions (plus the ordinary follow-up “Unable to elaborate statement”); the generic `pair#(int defaults)` specialized with class types compiles and runs. Initializer and resolved-property forms each reject once. Function-return and ternary RHS probes still compile with only the existing compile-progress warning; these limitations and the netmisc fallback warning are tracked in DD-141.

This records focused local evidence only. T0 smoke, pinned UVM, full T1, Fast Linux, and T2 qualification are pending at this point.
