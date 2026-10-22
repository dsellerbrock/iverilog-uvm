# Candidate issue draft — lead review required; not filed

**Title:** [IEEE 1800] §23.4 — nested module declared and instantiated in the same scope is rejected

**Observed reproduction:** Compile `tests/1800_audit/c23/p23_04f_nested_module_scope.sv` with the pinned Icarus binary in both `-g2017` and `-g2023` modes. Both stop at `inner u()` with `Unknown module type: inner`; neither reaches runtime. Runner and raw logs are in this directory.

**Standard:** IEEE 1800-2017 and IEEE 1800-2023 §23.4: “A module can be declared within another module” and is visible when “declared and instantiated in the same scope.” The nested module also references an enclosing variable.

**Dedupe:** All-state repository searches for `nested module` and `23.4` found no issue covering this. Search results such as #672 and #478 concern unrelated class/constraint behavior. Full search record: [`dedupe-live-20261020.txt`](dedupe-live-20261020.txt).

**Disposition:** Await lead confirmation/classification before filing.
