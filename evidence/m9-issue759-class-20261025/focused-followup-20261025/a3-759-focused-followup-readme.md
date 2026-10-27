# M9 #759 focused validation follow-up — 2026-10-25

This follow-up supersedes the earlier focused note. The first 14/14 legacy result included two false-positive 2023 compile-error rows: their wrappers used `ivtest/...`, so preprocessing failed and the expected-compile-error tests passed. Both wrappers now use `ivltests/...` and the suite was rerun.

A fresh local macOS build/install passed using `macslot localrun 900 sh -c 'make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex && make install'`. The final guard reads the `PEIdent`'s cached `expr_type()` and skips unspecialized/seed-derived class template scopes; it does not perform a second type-resolution pass.

The focused gate passed 14/14 legacy and 14/14 JSON/VVP tests. The positive generic-class test now also compiles `chandle` null and identifier assignments. The unrelated `sv_class_static_fixed_array_container_element_read_fail` passed through both runners; JSON stderr contains exactly two expected `sorry: this indexed static-property read form is not yet supported.` diagnostics.

For each of the 12 compile-error JSON cases, stderr contains exactly one §6.22.5 diagnostic and no `Include file ... not found` or preprocessor failure. Raw runner output and diagnostic-count verification are recorded alongside this note.

This is focused local evidence only. The final-code smoke, Slurm T1 selection, and pinned UVM gate are pending.
