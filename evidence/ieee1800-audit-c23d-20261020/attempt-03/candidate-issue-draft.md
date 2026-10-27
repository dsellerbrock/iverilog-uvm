# Candidate issue draft — lead review required; not filed

**Title:** [IEEE 1800] §23.5 — `extern module` declarations are syntax errors

**Observed reproduction:** Compile `tests/1800_audit/c23/p23_04b_extern_m.sv` and `tests/1800_audit/c23/p23_04c_extern_param.sv` in both `-g2017` and `-g2023` modes. Both the non-ANSI and parameterized ANSI forms fail at the initial `extern` token with a syntax error. Runner and raw logs are in this directory.

**Standard:** IEEE 1800-2017 and IEEE 1800-2023 §23.5 permit `extern module` declarations for separate compilation, both with ANSI port declarations (including parameters) and non-ANSI port lists.

**Dedupe:** All-state repository searches for `extern module` and `23.5` found no matching issue. #824/#823 concern modport exports, #841/#842 concern external constraints, and #641 concerns class extern-function return types. Full search record: [`dedupe-live-20261020.txt`](dedupe-live-20261020.txt).

**Disposition:** Await lead confirmation/classification before filing.
