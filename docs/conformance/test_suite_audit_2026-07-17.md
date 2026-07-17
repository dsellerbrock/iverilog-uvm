# Test-suite audit — 2026-07-17

Goal (as posed): *ensure the test suite is working properly, that every
failure is documented with a definitive breakage reason, and that no
failure is merely "flaky."*

This audit covers all four regression suites the project gates on:

| Suite | Harness | Count | Result |
|-------|---------|-------|--------|
| ivtest (external) | `vvp_reg.pl` (gold-diff) | 2559 | 2457 pass / **99 fail** / 3 expected-fail |
| UVM sweep | `.github/uvm_test.sh` (pattern-match) | 177 | 177 "pass" → **true 176/177** (1 masked) |
| bundled VPI | `ivtest/vpi_reg.pl` (gold-diff) | 81 | 81 pass |
| negative | `tests/negative/run_negative.sh` | 32 | 32 pass |

Headline conclusions:

1. **The `pow_*` "flaky" failures are not flaky** — they are a
   deterministic **out-of-memory kill** under memory contention. Root
   cause proven; see Part 2.
2. **ivtest is deterministic and its harness is sound.** With the machine
   quiet, the failing set is exactly 99 tests, reproducibly. Every one has
   a definitive reason (Part 3).
3. **The UVM sweep masks one real failure** (`reg_basic_test`) and rests on
   a broken UVM error counter. True pass rate is 176/177. See Part 4. This
   is the most material finding.
4. Of the 99 ivtest fails, the large majority are **cosmetic diagnostic
   drift** (gold files predate the fork's message rewording) or
   **intentional feature additions** (a rejection-test now compiles because
   the fork implemented the feature). A short list are genuine functional
   defects the suite is correctly catching (Part 5).

---

## Part 1 — Harness integrity

### 1.1 ivtest (`vvp_reg.pl`) — SOUND

- **Fully sequential.** No `fork`/threads anywhere; each test compiles to
  `./vsim`, runs `vvp vsim`, then deletes it. There is no concurrency, so
  "concurrent-load flake" was never a possible diagnosis.
- **No silent-pass path.** For tests with a gold file → exact diff (with
  optional line-skip / unordered compare). For "normal" tests *without* a
  gold file (e.g. the `pow_*` tests) → `Diff.pm` requires a literal
  `^PASSED$` line in the output, so a crashed/empty/garbage run cannot pass.
  `CE`/`RE` tests require the compile/runtime error to actually occur (and
  distinguish a core dump). Counts reconcile exactly: 2559 = 2457 + 99 + 0
  NI + 3 EF.
- **Deterministic** modulo the `pow_*` OOM (Part 2). Two full runs plus a
  quiet run confirmed the stable set is exactly the 99 in `base_norm`.

### 1.2 bundled VPI (`vpi_reg.pl`) — SOUND

Exact gold-diff (`diff("vpi_gold/<name>.log", "vpi_log/<name>.log")`) via
the same `Diff.pm`. Gold captures the `iverilog-vpi` build banner and the
`$finish` line, so the compare is exact and order-independent. 81/81.

### 1.3 negative (`run_negative.sh`) — MOSTLY SOUND

Requires each `tests/negative/*.sv` to fail compilation (non-zero exit)
**and** emit a loud `error:`/`sorry:` diagnostic. This delivers the primary
guarantee — a negative test that compiles clean fails the suite (catches
silent acceptance of illegal input). **Minor gap:** it accepts *any*
`error|sorry`, not the *specific* expected diagnostic, so a test could pass
for an unrelated rejection reason if a future change moves the error.
Recommend per-test marker matching.

### 1.4 UVM sweep (`.github/uvm_test.sh`) — WEAKEST; two compounding holes

The sweep scores by grepping the run output: it checks a set of PASS
patterns (`PASS`, `data=ab`, …) **first**, and only if none match does it
check FAIL patterns (`FAIL|UVM_ERROR|UVM_FATAL|Invalid opcode|Program not
runnable`); if neither matches it scores `PASS (no-check)`.

- **Hole A — masking.** Because PASS is checked before FAIL, a test that
  prints any "PASS" substring is scored pass even if it also emits
  `UVM_ERROR`/`UVM_FATAL`. This is not hypothetical — `reg_basic_test`
  hits it (Part 4).
- **Hole B — broken error counter underneath.** The sweep can't rely on
  UVM's own error count because it doesn't work in this fork: a minimal
  test firing two `` `uvm_error `` calls prints two `UVM_ERROR` report
  lines but the summary still reports `UVM_ERROR :    0`. The report
  server's severity counter never increments. This is *why* the sweep uses
  ad-hoc string matching — and that workaround is what admits Hole A.
- **Hole C — `PASS (no-check)`.** Any test whose output matches neither
  pattern is scored pass. Currently 0 tests land here, but the fallback is
  a latent false-pass.

Recommendations in Part 6.

---

## Part 2 — The `pow_*` "flaky" tests: definitive mechanism (OOM)

**Symptom:** across runs, a *rotating* subset of `pow_ca_signed`,
`pow_ca_unsigned`, `pow_reg_signed`, `pow_reg_unsigned` fails with
"Failed - running vvp" and a **0-byte log**.

**Mechanism (proven):**

- Each `pow_*` test exhaustively sweeps `a ** b` over a 16-bit × 8-bit
  space with 128-bit accumulators and a per-iteration `#0`. Measured peak
  **RSS ≈ 2.87 GB** per process, ~10 s runtime.
- Standalone on a quiet machine each **passes deterministically** (verified
  3/3, exit 0, `PASSED`).
- The session cgroup's `memory.oom_control` shows **`oom_kill 6`** and
  `memory.max_usage_in_bytes` = **15.9 GB** against a 16 GB physical
  ceiling. When any other memory-heavy process runs concurrently, total
  RSS exceeds RAM and the kernel **SIGKILLs** a `pow_*` process. A killed
  process flushes nothing → 0-byte log → non-zero exit → harness prints
  "Failed - running vvp".
- This is exactly why the failing set *rotated* run-to-run — it tracked
  whatever else was running. Two back-to-back full runs killed different
  subsets (3 vs 1); a third run with the machine kept **quiet** produced
  **99 failures and all 7 `pow_*` tests PASS**, matching `base_norm`
  exactly.

**Verdict:** environmental memory-exhaustion OOM, not a defect in iverilog
or in the tests, and not nondeterminism in the tool. On a host with
≥ ~4 GB free per concurrent heavy job (or by not running the suite
alongside a parallel build), the `pow_*` tests are fully deterministic. The
prior "documented concurrent-load flake" label was imprecise; the precise
statement is above.

---

## Part 3 — The 99 ivtest baseline failures, by category

Every failure was reproduced from a clean run and root-caused from its log
+ source + gold diff. They group as follows (full per-test table at the
end).

### 3a. Cosmetic diagnostic / output drift — NOT functional (largest group)

The fork modernized compiler diagnostics; the gold files predate it. These
tests still reject bad code correctly or still compute correct values —
only the *message text* or an *incidental output line* differs. Examples:

- Message rewording / capitalization: `missing`→`Missing`, `malformed`→
  `Malformed`, `choosing`→`Choosing`, `of copy expects 2 bits, got N`→`of
  module copy expects 2 bit(s), given N`, `reg/register`→`variable`,
  backtick-quoting identifiers, richer scope/instance/module detail.
  (`br1027a/c/e`, `br_gh79`, `br_gh127a–f`, `pr1792152`, `pr1833024`,
  `pr1866215/b`, `pr2976242c`, `pr3190941`, `pr3366217d`, `pr2800985b`,
  `sv_*_fail`, `sv_default_port_value3`, `sv_end_label*`,
  `sv_timeunit_prec_fail1/2`, `sv_wildcard_import5`, `uwire_fail`, …)
- Scope-name formatting: `$unit`→`$unit::`, `pkg`→`pkg::`
  (`br1003a–d`).
- Stale line numbers in gold (`pr1723367`), dropped constant-condition or
  wait-constant warnings (`pr987`, `pr1862744b`).
- VCD writer emits a parameter-dump block absent from old gold
  (`array_dump`, `dump_memword`, `vcd-dup`, `pr2859628`).

**Risk: none.** These are stale-gold mismatches, not regressions.

### 3b. Intentional feature-now-supported (stale `CE`/reject gold)

The fork implemented a construct that the test was written to see
*rejected*, so the rejection-gold no longer matches:

- Deferred assertions (`sv_deferred_assert1/2`, `sv_deferred_assume1/2`) —
  the `sorry: Deferred assertions are not supported` gate was lifted. Note
  the runtime is incomplete (syntax accepted, no assertion output yet), so
  these golds should be **regenerated** once execution is wired.
- Queues in classes (`br1005`), unpacked struct (`br_ml20150315b`),
  string→vector assignment (`br_ml20180227`), enum casts
  (`br_gh130b`, `br_gh386d`).

**Risk: none** (working as designed) — but several golds are now stale and
should be refreshed to keep the tests meaningful.

### 3c. Pre-existing UNIMPL gaps outside fork scope

- Verilog-AMS / analog: `analog1`, `analog2` (`V(out)` probe, `<+`
  contribution). 
- VHDL (`vhdlpp`): `vhdl_fa4_test4`, `vhdl_inout`, `vhdl_multidim_array`.
- Legacy split task/function port typing (`input l; reg[4:0] l;`):
  `pr1841300`, `pr1960619`, `pr2001162`, `task_iotypes`, `automatic_task`,
  `constfunc8`.
- Module-header package import (`module m import p::*; #(...)`):
  `mod_inst_pkg`.
- Implicit-net-used-before-declared strictness: `pr1909940`, `pr1909940b`.
- defparam-on-missing/localparam now a hard error vs a warning: `pr498`,
  `br_gh157`.
- Procedural assign/force to an array word: `array_lval_select3a`.

**Risk: none** for the SV/UVM effort — these are plain-Verilog / AMS / VHDL
areas the fork does not touch. (Attribution to upstream vs. an early fork
commit was not separately proven; see the caveat in Part 5.)

### 3d. Known runtime limitations — automatic-scope codegen

Automatic task/function locals used in edge/event controls or recursion:
`unresolved vvp_net reference`, segfault, or missing/`x`/wrong output.
`automatic_events`, `automatic_events2`, `automatic_events3`,
`automatic_task2`, `automatic_task3`, `recursive_task`, `func_init_var2`.
This is a long-standing iverilog automatic-variable limitation; the tests
correctly expose it.

### 3e. Upstream elaborator bug

`br_gh440` — `ivl_assert(le->expr_width() > 0)` in `eval_tree.cc:367`
aborts on `null <= 1`. `git blame` attributes the line to an **upstream**
commit (Cary R). Pre-existing; it is the regression test for the still-open
upstream GitHub issue #440.

### 3f. Genuine functional defects (see Part 5).

---

## Part 4 — UVM: the masked failure and the broken error counter

### `reg_basic_test` is a masked functional failure

Its output contains:

```
UVM_ERROR reg_basic_test.sv(95) @ 0: uvm_test_top [REG_TEST] FAIL: backdoor write status=1
UVM_ERROR reg_basic_test.sv(100) @ 0: uvm_test_top [REG_TEST] FAIL: backdoor read status=1
UVM_INFO  reg_basic_test.sv(108) @ 0: uvm_test_top [REG_TEST] PASS: mirrored value matches 0xAB
...
UVM_ERROR :    0
```

`UVM_BACKDOOR` register write/read return a non-OK status (=1) → two real
`` `uvm_error ``s fire. The mirror check (a *predicted* value, not the
backdoor path) passes and prints "PASS", so the sweep — checking PASS
before FAIL — scores the test green. **The test is actually failing:
UVM backdoor register access does not work.**

### Underlying: the UVM error counter never increments

A minimal test firing two `` `uvm_error ``s prints two `UVM_ERROR` lines
but still summarizes `UVM_ERROR :    0`. The report server's severity
counter is not wired, so the standard UVM pass/fail signal
(`get_severity_count(UVM_ERROR)==0`) is meaningless in this fork. This is a
real UVM-base gap independent of any one test.

### Exposure is bounded

Scanning all 177 captured outputs for genuine `UVM_(ERROR|FATAL) … @`
report lines: **exactly one** test (`reg_basic_test`) fired real errors.
The other 176 are legitimately clean (no error reports, PASS line present).
So the true UVM result is **176 pass / 1 masked fail**, and there are **0**
`PASS (no-check)` tests.

---

## Part 5 — Genuine functional defects the suite catches (verified)

These are real behavioral defects (not cosmetic, not intentional). Where I
reproduced them myself they are marked **VERIFIED**; the rest are as
reported by inspection and should be treated as candidates pending an
upstream diff (see caveat).

- **`event`-declaration ordering parser bug — VERIFIED.** An `event`
  declaration placed *after* any other declaration inside a task/block is
  rejected as `syntax error / Malformed statement`; `event`-first compiles.
  Minimal repro: `task t; real x; event e; ... endtask` fails, `task t;
  event e; real x; ...` passes. Root cause behind `always_comb_warn`,
  `always_ff_warn`, `always_latch_warn`, and `automatic_task`.
- **`reg`-array word read via continuous assign returns `z` not `x` —
  VERIFIED.** `wire [7:0] w = mem[0]` on an uninitialized reg array reads
  `zz`. (`pr1648365`, `pr2974294`.) Core cont-assign/array codegen.
- **`part_sel_port`** — multidim packed-array port part-select connection
  yields a wrong value (self-check prints FAILED).
- **`fork_join_dis`** — `disable` fails to terminate detached `join_any`
  children.
- **`sv_wildcard_import2` / `import3`** — valid code wrongly *rejected*: a
  local `typedef … word` that legitimately shadows a wildcard-imported
  `word` triggers `syntax error / Invalid module instantiation`.
- **`sv_wildcard_import4`** — fork "compile-progress fallback"
  instrumentation replaces the expected duplicate-import diagnostics.
- **`br_gh265`** — fork object-codegen (`draw_eval_object … emitting null
  fallback`, `git blame` → fork) reaches codegen instead of producing the
  elaboration-time implicit-cast rejection. Loud (a Warning), not a silent
  miscompile.
- **`reg_basic_test`** (Part 4) — UVM backdoor register access returns
  failure status.

### Corrected finding — `sv_queue_vec` is NOT a bug

An automated pass initially flagged `sv_queue_vec` as a wrong-value
regression (OOB read returns `0`, gold expects `'X`). This is **incorrect**:
its queue is `int q_tst[$]`, and `int` is **2-state**, so per IEEE 1800
§7.10.4 an out-of-bounds / unknown-index read returns the element default =
**0**. iverilog is LRM-conformant (verified: a 4-state `reg[31:0]` queue
correctly returns `x`); the gold's `'X` is stale. Recorded here because it
shows why gold-diff alone cannot classify a "regression."

### Attribution caveat (fork vs. upstream)

The gold files are *reference-simulator* output, not upstream-iverilog
output, so a gold mismatch does **not** by itself prove a fork regression —
many of these are almost certainly upstream-iverilog failures too (that is
why they are long-standing known-fails). `git blame` is unreliable for
attribution here because `parse.y` and other core files trace wholesale to
a fork reformat commit. **A definitive fork-vs-upstream split requires
building a pristine upstream iverilog and diffing the fail set** — not done
in this audit. The behaviors above are verified as *real*; their
*attribution* is the open follow-up.

---

## Part 6 — Recommendations

1. **UVM sweep hardening (highest priority).**
   - Fail a test if its output contains a real `UVM_ERROR`/`UVM_FATAL`
     report line (`UVM_(ERROR|FATAL) .*@`), regardless of any PASS
     substring — i.e. check failure evidence *before* success, or require
     both "PASS present" *and* "no error lines."
   - Treat `PASS (no-check)` as a hard FAIL (or require an explicit
     expected-output gold per test).
   - Fix the `uvm_report_server` severity counter so `UVM_ERROR :  N`
     reflects reality; then the sweep can trust the summary.
   - `reg_basic_test` should be reported as failing until UVM backdoor
     register access works.
2. **Document the `pow_*` OOM** in the suite notes: each needs ~3 GB free;
   don't run the suite alongside a parallel build. Optionally cap the
   sweep range so peak RSS stays < ~1 GB.
3. **Regenerate stale golds** for the intentional feature-now-supported
   tests (Part 3b), and consider re-baselining the cosmetic diagnostic
   golds (Part 3a) so real regressions aren't hidden in the noise.
4. **Negative suite:** match the specific expected diagnostic per test, not
   any `error|sorry`.
5. **File the verified functional defects** (Part 5): the `event`-ordering
   parser bug and the UVM error-counter gap are the two most impactful.
6. **Definitive attribution:** stand up an upstream-iverilog reference and
   diff the ivtest fail set to split fork-introduced from pre-existing.

---

## Appendix — full per-test reason table

Legend: **UNIMPL** = construct not implemented; **LENIENT** = expects a
compile-error the tool doesn't raise; **DIAG-DIFF** = correct rejection,
different message text; **OUTPUT-DIFF** = ran, output differs;
**RUNTIME-BUG** = vvp error/crash; **CRASH** = compiler abort.

The 99 names are exactly those in `base_norm` and reproduce
deterministically on a quiet host.

| # | Test | Category | Definitive reason |
|---|------|----------|-------------------|
| 1 | always_comb_warn | OUTPUT-DIFF (functional) | `event` decl after another decl in a task → "Malformed statement" (VERIFIED parser bug) |
| 2 | always_ff_warn | OUTPUT-DIFF (functional) | same event-ordering parser bug |
| 3 | always_latch_warn | OUTPUT-DIFF (functional) | same event-ordering parser bug |
| 4 | analog1 | UNIMPL | Verilog-AMS `V(out)` probe unsupported ("No function named `V`") |
| 5 | analog2 | UNIMPL | Verilog-AMS `<+` contribution → syntax error |
| 6 | array_dump | OUTPUT-DIFF (cosmetic) | VCD writer emits extra `$comment Show the parameter values.`/`$dumpall` block |
| 7 | array_lval_select3a | UNIMPL | "sorry: cannot %cassign to word of a variable array" (procedural assign/force to array word) |
| 8 | automatic_events | RUNTIME-BUG | automatic-task locals in edge events → 15× `unresolved vvp_net reference` |
| 9 | automatic_events2 | RUNTIME-BUG | same automatic-var edge-event codegen bug |
| 10 | automatic_events3 | RUNTIME-BUG | same (6× unresolved vvp_net reference) |
| 11 | automatic_task | UNIMPL/parser | `event` decl after a memory decl in a task rejected (event-ordering bug) |
| 12 | automatic_task2 | OUTPUT-DIFF (functional) | `@(array[i])` on automatic-task local never fires → zero output |
| 13 | automatic_task3 | RUNTIME-BUG | automatic-task local in `@(array[j])` → unresolved vvp_net + **segfault** |
| 14 | br1003a | OUTPUT-DIFF (cosmetic) | $printtimescale prints `$unit::` vs gold `$unit` |
| 15 | br1003b | OUTPUT-DIFF (cosmetic) | same `$unit::` scope-name formatting |
| 16 | br1003c | OUTPUT-DIFF (cosmetic) | same `$unit::` scope-name formatting |
| 17 | br1003d | OUTPUT-DIFF (cosmetic) | package scope `testpackage::` vs gold `testpackage` |
| 18 | br1005 | LENIENT (intentional) | SV queue-in-class now compiles+runs; gold expects `sorry` |
| 19 | br1027a | DIAG-DIFF | "Missing" vs gold "missing" task/function port direction |
| 20 | br1027c | DIAG-DIFF | same capitalization diff |
| 21 | br1027e | DIAG-DIFF | same capitalization diff |
| 22 | br_gh79 | DIAG-DIFF | "Malformed statement" vs gold "malformed statement" |
| 23 | br_gh127a | OUTPUT-DIFF (cosmetic) | port-width warning reworded (`of module copy expects 2 bit(s), given N`) |
| 24 | br_gh127b | OUTPUT-DIFF (cosmetic) | same warning rewording |
| 25 | br_gh127c | OUTPUT-DIFF (cosmetic) | same warning rewording |
| 26 | br_gh127d | OUTPUT-DIFF (cosmetic) | same warning rewording |
| 27 | br_gh127e | OUTPUT-DIFF (cosmetic) | same warning rewording |
| 28 | br_gh127f | OUTPUT-DIFF (cosmetic) | same warning rewording |
| 29 | br_gh130a | LENIENT | bare int→enum assign accepted (known-open gh#130) |
| 30 | br_gh130b | LENIENT (intentional?) | `enum'(1)` cast accepted; CE variant no longer errors |
| 31 | br_gh157 | DIAG-DIFF/strictness | defparam on localparam now hard-errors vs gold warn+run |
| 32 | br_gh265 | LENIENT/codegen | fork `draw_eval_object … null fallback` replaces elab cast-reject (blame→fork; loud) |
| 33 | br_gh315 | UNIMPL/config | `.A` implicit named-port needs SV; normal mode rejects (CE variant OK) |
| 34 | br_gh386c | LENIENT | continuous int→enum assign accepted (known-open gh#386) |
| 35 | br_gh386d | LENIENT (intentional?) | `assign = enum'(1)` cast accepted; CE variant no longer errors |
| 36 | br_gh440 | CRASH | `eval_tree.cc:367` assert abort on `null<=1` (blame→**upstream**; known-open gh#440) |
| 37 | br_gh497a | RUNTIME-BUG | packed 2-D `wire[3:0][3:0]` part-select assign → all-`z`, self-check FAILED (known-open gh#497) |
| 38 | br_ml20150315b | LENIENT (intentional) | unpacked struct now accepted; test expects compile error |
| 39 | br_ml20150606 | OUTPUT-DIFF (functional) | port + separate net redecl (`input[3:0] X; wire[3:0] X;`) now "already declared" |
| 40 | br_ml20180227 | LENIENT (intentional) | `reg[127:0]=string` assignment now accepted |
| 41 | br_ml20190814 | OUTPUT-DIFF | extra "SDF WARNING: …TIMINGCHECK not supported" line (specify/SDF, not SV) |
| 42 | case_unique | OUTPUT-DIFF (dropped diag) | "sorry: Case unique/unique0 qualities are ignored" no longer emitted; still PASSED |
| 43 | constfunc8 | UNIMPL | `reg bool [5:0] value;` malformed 2-word type decl rejected |
| 44 | dump_memword | OUTPUT-DIFF (cosmetic) | same extra VCD parameter-dump block |
| 45 | fork_join_dis | OUTPUT-DIFF (functional) | `disable` fails to kill detached `join_any` children |
| 46 | fread-error | OUTPUT-DIFF (dropped diag) | `$fread` "first argument must be a reg or memory" error no longer emitted |
| 47 | func_init_var2 | OUTPUT-DIFF (functional) | automatic-fn `automatic int acc=1` initializer ignored in const-fn eval → wrong value |
| 48 | macro_with_args | OUTPUT-DIFF (cosmetic) | macro-arg stringification adds trailing spaces `(a )` vs `(a)` |
| 49 | mod_inst_pkg | UNIMPL | package import in ANSI module header not implemented |
| 50 | part_sel_port | OUTPUT-DIFF (functional) | multidim packed-array port part-select → wrong value, FAILED |
| 51 | pr1002 | OUTPUT-DIFF (functional) | comb cont-assign lags one delta → stale compare → spurious CHECK FAILED |
| 52 | pr1648365 | OUTPUT-DIFF (functional) | `wire=reg_array[idx]` uninit word reads `z` not `x` (VERIFIED) |
| 53 | pr1723367 | OUTPUT-DIFF (cosmetic) | warning line numbers off (stale gold; sim output matches) |
| 54 | pr1792152 | DIAG-DIFF | `choosing typ expression`→`Choosing` (result matches) |
| 55 | pr1833024 | DIAG-DIFF | reworded elaboration errors, added scope/detail |
| 56 | pr1841300 | UNIMPL | legacy split function-port typing "Scalar port has vectored net decl" |
| 57 | pr1862744b | DIAG-DIFF | dropped two constant for-loop-condition warnings |
| 58 | pr1866215 | DIAG-DIFF | port-width warning reworded (`bits, got`→`bit(s), given`) |
| 59 | pr1866215b | DIAG-DIFF | same port-width warning rewording |
| 60 | pr1909940 | UNIMPL/strictness | implicit net used-before-declared rejected; gold expects PASSED |
| 61 | pr1909940b | UNIMPL/strictness | same implicit-net "declaration after use" |
| 62 | pr1960619 | UNIMPL | legacy split function-port typing (7×) |
| 63 | pr2001162 | UNIMPL | legacy split function-port typing (`_$Fadd32`) |
| 64 | pr2792883 | LENIENT | accepts `parameter W=dut.W;` hierarchical param ref that CE test expects rejected |
| 65 | pr2800985b | DIAG-DIFF | `$ferror` `(register)`→`(variable)` SV terminology (still rejects) |
| 66 | pr2859628 | OUTPUT-DIFF (cosmetic) | VCD parameter-dump block absent from 2009-era gold |
| 67 | pr2974294 | OUTPUT-DIFF (functional) | same reg-array-word-reads-`z` bug as pr1648365 → FAILED |
| 68 | pr2976242c | DIAG-DIFF | identifiers backtick-quoted vs bare in gold |
| 69 | pr243 | OUTPUT-DIFF (functional) | same-time `$monitor` vs `$finish(0)` ordering → missing final line |
| 70 | pr3190941 | DIAG-DIFF | reworded "…support a continuous assignment" + scope prefix |
| 71 | pr3366217d | DIAG-DIFF | SV enum-name-sequence errors capitalized (still rejects) |
| 72 | pr498 | UNIMPL/strictness | defparam on missing param now hard error vs gold warn+PASSED |
| 73 | pr987 | OUTPUT-DIFF (dropped diag) | `wait(0)` "will block permanently" warning no longer emitted |
| 74 | recursive_task | OUTPUT-DIFF (functional) | recursive automatic task via automatic vars yields `x`, no recursion |
| 75 | sv_deferred_assert1 | LENIENT (intentional) | deferred-assert gate lifted; compiles, no runtime output yet (regen gold) |
| 76 | sv_deferred_assert2 | LENIENT (intentional) | same |
| 77 | sv_deferred_assume1 | LENIENT (intentional) | same (assume form) |
| 78 | sv_deferred_assume2 | LENIENT (intentional) | same |
| 79 | sv_default_port_value3 | DIAG-DIFF | correct reject, richer message + `wire or reg`→`net or variable` |
| 80 | sv_end_label_fail | DIAG-DIFF | correct reject (15 err), more-detailed end-label messages |
| 81 | sv_end_labels_bad | DIAG-DIFF | same detailed-vs-generic end-label wording |
| 82 | sv_queue_real | OUTPUT-DIFF (dropped diag) | reworded delete-on-empty msg + dropped 2 undef-index warnings; **data correct** |
| 83 | sv_queue_real_fail | DIAG-DIFF | correct reject (9 err); wording only |
| 84 | sv_queue_string | OUTPUT-DIFF (dropped diag) | same as sv_queue_real; **data correct** |
| 85 | sv_queue_string_fail | DIAG-DIFF | correct reject; wording only |
| 86 | sv_queue_vec | OUTPUT-DIFF (**not a bug**) | OOB read of 2-state `int` queue = 0 is **LRM-correct**; gold's `'X` is stale |
| 87 | sv_queue_vec_fail | DIAG-DIFF | correct reject; wording only |
| 88 | sv_timeunit_prec_fail1 | DIAG-DIFF | correct reject; casing/prefix + `_`-separator now accepted |
| 89 | sv_timeunit_prec_fail2 | DIAG-DIFF | same |
| 90 | sv_wildcard_import2 | UNIMPL/wrong-reject | local `typedef word` shadowing wildcard import wrongly rejected |
| 91 | sv_wildcard_import3 | UNIMPL/wrong-reject | same wildcard-import shadowing reject |
| 92 | sv_wildcard_import4 | DIAG-DIFF (behavioral) | fork "compile-progress fallback" masks expected duplicate-import errors |
| 93 | sv_wildcard_import5 | DIAG-DIFF | correct reject; `Ambiguous use of type 'word'` vs gold `Ambiguous use of 'word'` |
| 94 | task_iotypes | UNIMPL | legacy split task-port typing rejected |
| 95 | uwire_fail | DIAG-DIFF | correct reject; `Unresolved wire 'two'` vs gold `Unresolved net/uwire two` |
| 96 | vcd-dup | OUTPUT-DIFF (cosmetic) | same extra VCD parameter-dump block |
| 97 | vhdl_fa4_test4 | UNIMPL | vhdlpp: generics not bound / "Dimensions must be constant" |
| 98 | vhdl_inout | UNIMPL | vhdlpp inout continuous-assign strength restriction |
| 99 | vhdl_multidim_array | UNIMPL | vhdlpp multidim array in generate: "Scope index not constant" |

*(Per-batch source tables from the five root-cause passes are retained in
the session scratchpad under `findings/`.)*
