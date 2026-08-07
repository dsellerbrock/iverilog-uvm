# sv-tests + IEEE 1800-2023 Gap Ledger

## sv-tests Results (2026-08-06)

Ran all 1027 tests from [chipsalliance/sv-tests](https://github.com/chipsalliance/sv-tests).

| Metric | Count | % |
|--------|-------|---|
| Total tests | 1027 | 100% |
| **Pass** | **764** | **74%** |
| Fail | 263 | 26% |
| └ UVM tests (need `uvm_pkg` on cmd line) | 103 | 10% |
| └ Real failures | 160 | 16% |

**Non-UVM pass rate: 83%** (764/924)

### Failures by category

| Category | Count | Notes |
|----------|-------|-------|
| UVM package missing | 103 | Not compiler gaps — tests need `-I uvm-core/src uvm_pkg.sv` |
| Syntax errors | 100 | Real parser gaps |
| Preprocessor errors | 8 | Include/file resolution |
| Parameter issues | 8 | Default values, type mismatches |
| Sorry messages | 0 | ✅ All synthesis sorries fixed! |

### Failures by IEEE chapter (real, non-UVM)

| Chapter | Topic | Tests | Real Fails | % Fail |
|---------|-------|-------|-----------|--------|
| 5 | Lexical conventions | 50 | 10 | 20% |
| 6 | Data types | 84 | 15 | 18% |
| 7 | Aggregates (arrays/structs) | 103 | 8 | 8% |
| 8 | Classes | 53 | 21 | 40% |
| 9 | Processes | 46 | 4 | 9% |
| 10 | Scheduling semantics | 10 | 2 | 20% |
| 11 | Expressions | 88 | 12 | 14% |
| 12 | Procedural control | 27 | 9 | 33% |
| 13 | Tasks/functions | 15 | 1 | 7% |
| 14 | Clocking blocks | 5 | 1 | 20% |
| 15 | Interprocess sync | 5 | 0 | 0% ✅ |
| 16 | Assertions (SVA) | 52 | 8 | 15% |
| 18 | Coverage | 134 | 16 | 12% |
| 20 | Elaboration | 47 | 2 | 4% |
| 21 | Gate-level | 29 | 0 | 0% ✅ |
| 22 | Constraints | 75 | 26 | 35% |
| 23-26 | DPI/Compilation | 7 | 0 | 0% ✅ |

### Weakest areas

1. **Ch 8 (Classes)** — 40% fail: inheritance, parameterized classes, virtual methods
2. **Ch 22 (Constraints)** — 35% fail: distribution, implication, solve-before
3. **Ch 12 (Procedural control)** — 33% fail: foreach, do-while, break/continue
4. **Ch 18 (Coverage)** — 12% fail: cross coverage, transition bins

---

## IEEE 1800-2023 Feature Audit

iverilog-uvm currently targets IEEE 1800-2017 with partial 2023 support.

### Currently tracked 2023 features (2 total)

| Feature | Flag | Status |
|---------|------|--------|
| `$stacktrace` | `-g2023` | Supported |
| `.index` iterator method | `-g2023` | Supported |

### Major 2023 features NOT implemented

| Feature | IEEE Section | Priority |
|---------|-------------|----------|
| Interleaved assertions (`s_always`, `s_eventually`, `s_nexttime`) | 16 | High |
| Enhanced checker constructs | 17 | Low |
| `let` declarations in generate blocks | 3.11 | Medium |
| Enhanced package export/import | 26 | Low |
| Interface class improvements | 8 | Medium |
| Net type enhancements (`nettype`) | 6 | Low |
| `pure virtual` methods in classes | 8.20 | Medium |
| Enhanced DPI (`ref` arguments, open arrays) | 35 | Low |
| Randomization enhancements | 18 | Low |
| Assertion control tasks (`$assertpasson`, etc.) | 20 | Medium |

### Remaining "sorry" messages in codebase: 577

Top categories of active sorries:

| Category | Count | Location |
|----------|-------|----------|
| Concurrent assertion items | 10 | `parse.y` |
| Deferred assertions | 6 | `parse.y` |
| Covergroup bins | 6 | `parse.y` |
| Default disable iff | 4 | `parse.y` |
| Net delays | 4 | `elab_net.cc` |
| Timing checks | 3 | `parse.y` |
| Multi-dimensional arrays | 3 | various |

---

## Recommendations

### Quick wins (1-2 weeks each)

1. **Ch 8 — Class parameterization**: Fix `pkg::class #(...) var;` in modules (already identified as C5)
2. **Ch 22 — Constraint solver**: Distribution constraints, implication, solve-before
3. **Ch 18 — Coverage**: Cross coverage, transition bins
4. **UVMF integration**: Pre-compile UVM package in sv-tests test harness

### Medium term (1-3 months)

5. **Ch 6 — Data types**: Enum enhancements, packed unions, type reference
6. **Ch 11 — Expressions**: Streaming operators, type() operator, array manipulation
7. **Ch 16 — SVA**: Concurrent assertions, deferred assertions, default disable
8. **IEEE 2023**: `s_always`/`s_eventually`/`s_nexttime` assertion forms

### Long term

9. **Full IEEE 1800-2023 compliance**: Net types, checker constructs, DPI enhancements
10. **sv-tests CI pipeline**: Automated regression against all 1027 tests
