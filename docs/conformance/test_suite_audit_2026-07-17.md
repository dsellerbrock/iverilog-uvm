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
4. Of the 99 ivtest fails, an **upstream diff (Part 7)** shows **62 are
   pre-existing** (fail on upstream iverilog 13.0 too), **37 are
   fork-introduced regressions**, and 1 is a fork *fix*. Many are cosmetic
   diagnostic drift or intentional feature additions, but the 37 include
   genuine functional regressions (automatic-scope codegen, a class/null
   compile crash, an `event`-declaration parser bug, reg-array reads).
5. **Two fixes were implemented, not just recommended (Part 8):** the
   associative-array compound-assignment silent miscompile behind the
   broken UVM error counter is fixed in the compiler (`UVM_ERROR : 0` →
   real counts), and the UVM sweep is hardened so a failing test can no
   longer be masked by a stray "PASS".

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
  VERIFIED, now FIXED** (`pr1648365`, `pr2974294`; see Part 8 item 4): the
  vvp `.array/port` label was resolved eagerly inside `vpip_make_array`,
  before the caller allocated the word storage, so `array_attach_port`
  silently skipped scheduling the initial-value propagation.
- **`part_sel_port`** — RE-ATTRIBUTED on direct verification: upstream
  13.0 fails it identically (it is in the 62 pre-existing, not the 37).
  With **one** part-select port connection the value is visible at time 0;
  with **two** part-select drivers on the same net, the time-0 initial
  propagation has not resolved when the (delay-less) `initial` check
  reads — an inherited upstream propagation-ordering characteristic, and
  arguably an LRM time-0 race in the test itself. After any delay the
  value is exactly correct on both compilers. Not a fork miscompile; not
  fixed here (an upstream scheduler-semantics change with broad gold
  churn).
- **`fork_join_dis`** — `disable` fails to terminate detached `join_any`
  children. **FIXED** (Part 8 item 11): the unnamed-fork `$unm_blk` scope
  hid the children from `%disable` of the enclosing named block.
- **`sv_wildcard_import2` / `import3`** — valid code wrongly *rejected*: a
  local `typedef … word` that legitimately shadows a wildcard-imported
  `word` triggers `syntax error / Invalid module instantiation`.
- **`sv_wildcard_import4`** — fork "compile-progress fallback"
  instrumentation replaces the expected duplicate-import diagnostics.
- **`br_gh265`** — fork object-codegen (`draw_eval_object … emitting null
  fallback`, `git blame` → fork) reaches codegen instead of producing the
  elaboration-time implicit-cast rejection. Loud (a Warning), not a silent
  miscompile. **FIXED** (Part 8 item 10): the elaboration-time cast error
  is restored; output matches gold byte-for-byte.
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

### Attribution — now settled against upstream (see Part 7)

The initial version of this audit could not cleanly separate
fork-introduced from pre-existing failures (gold files are
*reference-simulator* output, and `git blame` is unreliable because core
files trace to a fork reformat commit). That gap is now closed: a pristine
**upstream Icarus Verilog 13.0** (fork base commit `9b44d55`) was built and
run over the same suite. The definitive three-way split is in **Part 7**.
Headline: **37 of the 99 are fork-introduced regressions**, 62 are
pre-existing (fail upstream too), and 1 test the fork *fixed*. Several
earlier hypotheses were corrected by this (the `automatic_*` cluster, the
reg-array `z`/`x` bug, and `br_gh440` are all fork-caused, not
pre-existing).

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

## Part 7 — Upstream attribution (definitive)

A pristine **upstream Icarus Verilog 13.0** was built from the fork's base
commit `9b44d55` (Cary R, 2026-02-20; fork work begins 2026-04-01) into a
separate prefix and run over the identical ivtest suite on a quiet host
(all 7 `pow_*` passed — no OOM). Diffing the fail sets:

| Class | Count | Meaning |
|-------|-------|---------|
| Pre-existing | **62** | Fail on upstream too — not the fork's doing |
| **Fork-introduced regression** | **37** | Pass on upstream, fail on the fork |
| Fork-fixed | 1 | Fails on upstream, passes on the fork (`unp_array_typedef`) |

So the "baseline-identical / no regressions" statement (true against the
mid-fork m4av baseline) does **not** hold against upstream: the fork's
SV/UVM work regressed **37** tests upstream passes. The 37, grouped by
nature (mechanism from the root-cause passes; attribution from the diff):

- **Automatic task/function variables (8)** — `automatic_events`,
  `automatic_events2`, `automatic_events3`, `automatic_task`,
  `automatic_task2`, `automatic_task3`, `recursive_task`, `func_init_var2`.
  Upstream runs these; the fork emits `unresolved vvp_net reference`,
  segfaults, or mis-evaluates the automatic-var initializer. **This
  corrects the earlier audit**, which guessed these were a "known iverilog
  limitation" — they are fork regressions.
- **Feature now accepted, CE-gold stale (7, intentional direction)** —
  `br1005` (queue-in-class), `br_ml20150315b` (unpacked struct),
  `br_ml20180227` (string→vector), `sv_deferred_assert1/2`,
  `sv_deferred_assume1/2`. Upstream emits the `sorry` the gold expects; the
  fork lifted the gate. Intended, but the deferred-assertion runtime is
  incomplete and the golds need regenerating.
- **Wildcard-import / scope rework (4)** — `sv_wildcard_import2/3`
  (wrongly rejects a local typedef shadowing an import), `sv_wildcard_import4`
  (compile-progress fallback masks the duplicate-import diagnostics),
  `sv_wildcard_import5` (message wording).
- **Enum leniency (2)** — `br_gh130a`, `br_gh386c` (int→enum accepted).
- **Queue diagnostic drift (2)** — `sv_queue_real`, `sv_queue_string`
  (data correct; dropped/reworded warnings).
- **Class/null (2)** — `br_gh440` (fork feeds the upstream
  `eval_tree.cc:367` width assert a zero-width `null` expression → abort;
  **the earlier blame-based "upstream" call was wrong** — the trigger is
  fork-introduced), `br_gh265` (fork object-codegen null fallback bypasses
  the elaboration cast check).
- **Reg-array-word continuous assign (2)** — `pr1648365`, `pr2974294`
  (`wire = reg_array[idx]` reads `z` not `x`). **Corrects the earlier
  "likely upstream" guess** — fork-introduced.
- **Dropped diagnostics / ordering (3)** — `pr987` (wait-constant warning),
  `pr1862744b` (for-loop-constant warnings), `pr243` (`$monitor`/`$finish`
  same-time ordering).
- **Parser / misc (7)** — `array_lval_select3a`, `case_unique`,
  `constfunc8`, `mod_inst_pkg`, `pr2792883`, `task_iotypes`, and the
  `event`-declaration-ordering parser regression (verified: upstream
  compiles `event` after another decl in a task, the fork rejects it —
  this also breaks `always_comb/ff/latch_warn`, which were already failing
  upstream for an unrelated warning-diff).

The remaining **62** pre-existing failures (analog/Verilog-AMS, VHDL,
legacy split ports, VCD parameter-dump formatting, upstream known-open
`br_gh*`/`pr*` bugs, diagnostic wording) fail identically on upstream and
are genuinely not the fork's responsibility.

## Part 8 — Remediation delivered in this pass

Two fixes were implemented and validated (not just recommended):

1. **Compiler: associative-array element compound assignment.**
   `a[k]++`, `a[k]+=x`, etc. were silently miscompiled — a local assoc
   corrupted the vvp object stack (crash), a class-member assoc silently
   dropped the store (value unchanged). This is the root cause of the
   broken UVM error counter (`int m_severity_count[uvm_severity];
   m_severity_count[sev]++` never incremented → `UVM_ERROR : 0`).
   `PAssign::elaborate_compressed_` (`elaborate.cc`) now detects an
   associative element l-value (local via `sig()->darray_type()`, class
   property via `get_prop_type(member_idx)`) and expands `a[k] op= rv` into
   the known-good plain store `a[k] = a[k] op rv`. Fixed-array, dynamic-array
   and scalar compound assigns are untouched. After the fix a minimal UVM
   test firing two `` `uvm_error ``s reports `UVM_ERROR : 2`. Note upstream
   iverilog does not implement `int a[int]` at all, so this completes a
   fork-added feature rather than restoring upstream behavior. Regression
   test: `tests/assoc_compound_assign_test.sv`. Validated: ivtest
   baseline-identical (99, no new fails), bundled VPI 81/81, negative 32/32.
2. **UVM sweep hardening** (`.github/uvm_test.sh`). Failure evidence is now
   checked **before** any PASS marker: a real `UVM_(ERROR|FATAL) … @` report
   line, a non-zero UVM summary count, an explicit `FAIL`, or a vvp image
   rejection scores the test FAIL regardless of any "PASS" substring. A run
   with no PASS marker and no error is now a FAIL (was a silent
   `PASS (no-check)`). `reg_basic_test` is documented in `KNOWN_FAIL` with
   its reason (UVM_BACKDOOR needs DPI HDL access, disabled under
   `-DUVM_NO_DPI`) instead of being silently masked.
3. **Compiler: automatic named-block variable initializer in constant
   functions** (`elaborate.cc`, `PBlock::elaborate`). An automatic local
   declared with an initializer inside a *named* begin/end block
   (`begin:blk automatic int acc = 1; …`) had its initializer elaborated
   only into the block's activation-frame prefix (scope 0). At runtime the
   frame resolves it, but constant-function evaluation walks the block
   statements in the block's own scope context and could not resolve the
   scope-0 assignment target, so the initializer was silently dropped and
   the automatic local kept its default. The fix records a second,
   block-scoped copy of the initializers as the scope's `var_init` purely
   for the evaluator — `var_init()` is read *only* by the constant-function
   evaluator (`net_func_eval.cc`), never by code generation, so the runtime
   path is byte-for-byte unchanged. (A first attempt that instead appended
   the initializers to the block body like upstream regressed a passing
   UVM test — `configdb_assoc_test` hung — because the fork wraps the block
   in a `NetAlloc`/`NetFree` activation frame that upstream does not; the
   const-eval-only approach sidesteps that interaction entirely.) Fixes
   `func_init_var2` (ivtest 99→98, zero new regressions; reentrancy and the
   `configdb_assoc_test` no-hang both verified). Regression test
   `tests/auto_block_var_init_test.sv`.

### Automatic task/function variable cluster — root causes (partial fix)

The upstream diff flagged 8 automatic-variable regressions. Their precise
mechanisms (from this pass), so the remaining work is well-scoped:

- **`func_init_var2`** — automatic named-block var initializer dropped in
  constant-function eval. **FIXED** (item 3 above).
- **`automatic_events3`** — an event sensing a **bit-select** inside an
  automatic task (`@(posedge Source[0])`) lowered the bit-select to a
  synthesized local `.part` net, which is elided when the scope is drawn,
  yet `draw_input_from_net` (`tgt-vvp/vvp_scope.c`) still emitted the elided
  net's `v…` label as the event operand → runtime `unresolved vvp_net
  reference`. **FIXED**: `draw_input_from_net` now returns the nexus driver
  (the `.part` functor `L_…`, as upstream does) when the resolved signal is
  a local/automatic net (matching the elision condition), exempting
  class/object signals so value-change and virtual-interface events are
  unaffected. Regression test `tests/auto_task_bitselect_event_test.sv`.
  ivtest 98→97, UVM 178/0/1, VPI 81/81, negative 32/32 — zero regressions.
- **`automatic_events`, `automatic_task2`, `automatic_task3`,
  `fork_join_dis`** — **FIXED** by an unrelated-looking but shared root
  cause: the fork's `K_fork` grammar action (`parse.y`) lacked the
  empty-scope elision the `K_begin` action already had, so an **unnamed
  `fork…join` with no declarations of its own** (the inner fork of a task,
  whose loop/IO variables belong to the enclosing task) kept a synthesized
  `$unm_blk` scope. Because the task is automatic, the backend then
  allocated a **spurious per-block activation frame** for that empty scope,
  which became the current activation context and broke resolution of the
  enclosing task's per-invocation locals — under concurrent invocation the
  locals read `x` (`automatic_events`), and the same stray scope corrupted
  the array-word event path (`automatic_task2` no output / `automatic_task3`
  segfault) and `disable`-of-detached-`join_any` (`fork_join_dis`).
  Dropping the empty unnamed-fork scope (matching the begin/end path, and
  the reference compiler, which keeps such locals in the single task frame)
  fixes all four. ivtest 97→93, UVM 178/0/1, VPI 81/81, negative 32/32,
  bison conflicts unchanged. Regression test
  `tests/auto_task_concurrent_frame_test.sv`.
  *Correction:* the elision initially covered every join type, but the
  join_none case broke UVM (`uvm_objection::m_init_objections` has a
  `fork…join_none` task call inside a *function*; without the fork scope
  the checker saw an illegal direct task call), so it was restricted to
  blocking `join` — which re-broke `fork_join_dis`. Part 8 item 11 settles
  this properly: elide for all join types *except lexically inside a task
  or function*, keeping the UVM deferred-call and process-identity
  behavior while restoring `disable` reachability of detached children.
- **`automatic_events2`** — the *deeper* remaining case, now root-caused to
  a precise, minimal trigger: **a blocking `fork … join` inside an automatic
  task where one branch ends before a sibling branch reads a parent-scope
  automatic local**. The sibling's read then returns the element default
  instead of the live value (in `automatic_events2` this is why only the
  events fired by the module signal `any`, *after* the driver branch has
  finished, print `x` — the earlier `pos`/`neg`-driven events are correct).
  Minimal repro (not concurrency-dependent; single invocation reproduces):

  ```
  task automatic w(input byte id, output byte r);
    begin: body
      reg [7:0] acc; acc = id;
      fork
        begin #10 ; end          // branch A ends early
        begin #30 r = acc; end   // branch B reads parent local after A ended
      join
    end
  endtask                        // r reads 0, expected id
  ```

  `IVL_CTX_TRACE` shows `body` is `alloc-shared` with the task frame, and
  when branch A is reaped the shared parent context is dropped from the
  chain the still-live sibling reads through. The fix lives in the vvp
  runtime context lifecycle (`of_ALLOC`/`of_FREE`/`do_join`/`vthread_reap`
  and the `automatic_context_refcount` bookkeeping) — a large, intricate,
  fork-specific subsystem that underlies **every** automatic task/function
  (hence all of UVM), so the blast radius of a wrong change is severe. This
  is left scoped for a dedicated, heavily-validated pass (or the
  architectural move to the reference compiler's single-task-frame model,
  where nested block/fork locals live in the one task frame and this class
  of bug cannot arise).
- **`automatic_task`** — a plain `event` declaration placed *after* another
  declaration in a task is rejected (`syntax error / Malformed statement`);
  upstream accepts it. This is the same fork parser regression that breaks
  `always_comb/ff/latch_warn`, rooted in the fork's grammar additions
  (~1584 LALR conflicts vs upstream's handful); a safe fix requires
  isolating the specific conflicting rule.
- **`recursive_task`** — a recursive automatic task returning through an
  automatic output var, with an `@f` wait on that var inside a fork/join,
  yields `x`; combines the automatic-var event-sensing issue above with
  recursion.

Remaining (`automatic_events2`, `automatic_task`, `recursive_task`) are
genuine but deeper (per-block-frame parent linkage, parser-conflict
isolation) and are left scoped rather than rushed.

### Silent-miscompile pass (wrong-value / crash cluster)

4. **vvp: array-word initial value never propagated through a continuous
   assign** (`pr1648365`, `pr2974294` — the audit's verified reg-array
   `z`-instead-of-`x` bug). The fork had added an eager
   `compile_resolve_pending_label(label)` inside `vpip_make_array`
   (`vvp/array.cc`); a `.array/port` compiled before its `.array` resolved
   at that moment — **before the caller allocated the word storage** — so
   `array_attach_port`'s `vals4 || vals` guard failed and the
   initial-value propagation was silently never scheduled. The driven net
   kept its `z` default forever (unless the word was later written). The
   resolve now runs at the end of each `compile_*_array` variant, after
   storage exists. Both tests now pass (`pr1648365` matches gold,
   `pr2974294` prints PASSED). Regression test
   `tests/array_word_init_prop_test.sv`.
5. **elaborator: literal `null` in illegal operator/r-value contexts was
   silently accepted or crashed** (`br_gh440`). The fork's compile-progress
   class-type leniencies (PEBinary / PEBComp / PEBLeftWidth / PEUnary
   `test_width`, and the `elab_and_eval` class-r-value fallback in
   `netmisc.cc`) treated *any* class-typed operand as a stubbed method
   return: `val = null` silently compiled to `val = 0`, `1|null`,
   `null<<1`, `!null` were silently accepted, and `null <= 1` let a
   width-0 null reach `eval_tree.cc`'s `must_be_leeq_` assertion →
   compiler abort. The leniencies are now gated with surgical precision —
   the first attempt was too coarse and broke UVM compilation (181
   COMPILE_FAIL), which pinned exactly which shapes the leniency
   legitimately serves:
   - **operator operands** (PEBinary/PEBLeftWidth/PEUnary): a literal
     `null` operand always errors; class-typed *expressions* keep the
     leniency (stubbed method returns).
   - **relational comparison**: class/null operands are a hard error in
     every language mode (never legal SV), and `PEBComp::elaborate_expr`
     bails out before building a `NetEBComp` with a class/null operand so
     the constant folder cannot abort.
   - **equality comparison**: `null` vs a **literal constant**
     (`0 == null`) errors; `null` vs an identifier stays lenient — the
     identifier's scalar type may come from a class type parameter
     instantiated with a scalar (`uvm_pair`'s `T1 f = null; if (f ==
     null)`), and `unresolved == null` is the canonical stubbed-handle
     comparison.
   - **r-value fallback** (`netmisc.cc`): a literal `null` with a 4-state
     LOGIC target errors (`logic v = null`, implicit-logic `return
     null`); a 2-state BOOL target keeps the fallback because `chandle`
     lowers to a 2-state atom and `return null` from a `chandle` function
     is legal SV (`uvm_svcmd_dpi`). Operator nodes typed class are always
     excluded from the fallback.
   `br_gh440` now matches its gold byte-for-byte AND the full UVM sweep
   stays green. Negative test `tests/negative/null_illegal_contexts.sv`.
7. **parser/scope: wildcard-import cluster** (`sv_wildcard_import2/3/4/5`)
   — two distinct fork defects, neither actually import *semantics*:
   - **Module-level `typedef_type v = init;` failed to parse** ("Invalid
     module instantiation"). The fork parses `TYPE_IDENTIFIER name;`
     through a no-port instantiation shape it added (upstream has no bare
     `IDENTIFIER` gate_instance at all) and reinterprets it as a variable
     declaration in `pform_make_modgates` — but `gate_instance` had no
     `= expr` alternative, so ANY module-level typedef'd declaration with
     an initializer was a syntax error (this, not shadowing, is what broke
     `sv_wildcard_import2/3`). `gate_instance` now carries the declarator
     initializer through `lgate::decl_init` into the reinterpretation
     (bison conflict counts unchanged), and a real instantiation with an
     initializer is a loud error.
   - **The lexer's is-this-a-type probe pinned wildcard imports as if
     referenced.** `pform_test_type_identifier` fires for every
     identifier, so the fork had to drop wildcard pins unconditionally in
     `add_local_symbol` — which destroyed the required declare-after-use
     error (IEEE 1800-2017 26.3, `sv_wildcard_import4`) and
     double-reported ambiguity. A first fix (probe fully read-only) broke
     UVM elaboration (class-property types stopped resolving), proving
     the pins are a load-bearing *resolution cache* for later phases. The
     final design separates the two concerns: the probe still pins
     **unambiguous** hits as a cache but is silent and never reports
     ambiguity; a new `LexicalScope::wildcard_pin_used` set records
     *genuine* references (value uses via `check_potential_imports`, type
     uses via `pform_set_type_referenced` — including the
     modgate-reinterpretation declaration path, which now records the
     type reference); and `add_local_symbol` shadows an **un-used**
     wildcard pin but hard-errors on a **used** one (or any explicit
     import).
   Result: `sv_wildcard_import2/3` run and print PASSED,
   `sv_wildcard_import4` matches its gold byte-for-byte, and
   `sv_wildcard_import5`'s ambiguity diagnostics now match gold exactly
   too (the duplicated "type" wording came from the probe). Regression
   test `tests/typedef_init_shadow_test.sv`.

8. **parser: event declarations after other declarations** (`automatic_task`
   + the fork-specific half of `always_comb/ff/latch_warn`). Root cause
   found by tracing the LALR machine (env-gated `IVL_PARSE_TRACE` yydebug
   plumbing added for this): a leading *variable* declaration in a
   task/function/block body reduces OUT of the declaration section — the
   r/r conflict between empty `K_const_opt` (stay) and the empty
   declaration-list (exit) resolves by rule order toward exit — and the
   declaration parses via the fork's inline *statement* declaration rule.
   That worked for variables, but statement context had no event rule, so
   `event e;` after any variable declaration exploded as "Malformed
   statement" (while `event` FIRST worked, since `K_event` shifts directly
   in the declaration states — the exact observed asymmetry).
   `statement_item` now accepts `K_event event_variable_list ';'`
   (IEEE 1800-2017 6.18 permits declarations intermixed with statements),
   registered identically to the block_item_decl path. The +20 s/r
   conflicts this adds are all `K_event` shift-vs-exit-reduce pairs where
   both resolutions parse the same construct through `pform_make_events`.
   `automatic_task` now matches its gold; the `always_*_warn` trio reaches
   exact upstream parity — the only remaining diff (6 lines, identical on
   upstream 13.0) is a typo in the gold file itself ("Assinging"), i.e.
   pre-existing stale gold, not the fork. Regression test
   `tests/event_decl_order_test.sv`.
9. **`part_sel_port` re-attributed** — verified pre-existing upstream
   time-0 propagation ordering (see the corrected Part 5 entry), not a
   fork miscompile; left unfixed deliberately.
10. **elaborator: darray/queue targets accepted arbitrary vectorable
   r-values** (`br_gh265`). The Phase-11 compile-progress leniency in the
   typed `elab_and_eval` (`netmisc.cc`) — added so a runtime-bounds queue
   slice `q[lo:hi]` (which lowers as LOGIC through the bit-select fallback)
   could reach a queue target — let *any* vectorable expression through to
   a darray/queue l-value. `array = 8'd1 << 4;` then reached the object
   code generator, which warned (`draw_eval_object … emitting null
   fallback`) and silently stored null. The leniency is now gated on the
   expression being identifier-rooted (`PEIdent`), the only shape a queue
   slice can take; every other vectorable r-value takes the upstream
   elaboration error ("cannot be implicitly cast to the target type").
   `br_gh265` now matches its gold byte-for-byte. Negative regression
   test `tests/negative/darray_scalar_assign.sv`.
11. **parser/runtime: `disable` of a named block did not kill detached
   join_any/join_none children of an unnamed fork beneath it**
   (`fork_join_dis`). The fork synthesizes a `$unm_blk` scope for every
   unnamed fork; children `%fork` into that child scope, and vvp's
   `%disable` of the enclosing block's scope never reaches threads in the
   child scope (upstream never creates the scope — children run directly
   in the enclosing scope, so `disable` finds them). The empty unnamed-fork
   scope elision (item above) is now extended from blocking `join` to
   join_any/join_none, with one exception: lexically inside a *task or
   function* the scope is kept. In a function it is what distinguishes a
   deferred task call in a forked process from an illegal direct task call
   (UVM `uvm_objection::m_init_objections` relies on this — the exact
   breakage that forced the earlier restriction). In a task the runtime
   marks a `%fork` child whose target scope is a task scope as a compiled
   task call sharing the caller's logical process (`vvp/vthread.cc`
   `of_FORK`), so eliding there aliased `process::self()` in the forked
   process with the caller — verified live as 4 UVM sweep failures
   (`m6_process_identity_test` "watcher process aliases caller process",
   plus the `vif_smoke`/`vif_smoke_v2`/`seq_trace_test` sequencer-handshake
   deadlocks) before the exception was widened to routines. New pform
   helper `pform_scope_in_routine()` walks the lexical scope chain.
   `fork_join_dis` passes; UVM sweep fully restored. Known residual: a
   `disable` of a named block *inside a task* still cannot reach detached
   children of an unnamed fork there (the scope is deliberately kept);
   fixing that requires the runtime to identify compiled task-call forks
   without inferring from the target scope type. Regression test
   `tests/fork_disable_detached_test.sv` (covers both disable shapes plus
   the function/join_none exception).

## Part 9 — Re-baseline onto the vendored (live) ivtest suite (2026-07-18)

While chasing the "diagnostic-drift long tail" (br1027a/c/e, br_gh79,
br_gh127a–f, br1003a–d, array_dump, dump_memword — 16 tests), attribution
turned up something bigger than any single fix: **all 16 print
byte-identical output on the fork and on pristine upstream 13.0.** The
"drift" was never in either compiler — it was in the *gold files* of the
external ivtest checkout the gates had been running
(`/home/user/ivtest`), which is the **archived, obsolete ivtest
repository** (HEAD: "Note that this project is obsolete"). Upstream moved
the test suite into the iverilog tree; the fork's vendored `ivtest/`
directory is that live suite, its golds are current (293 gold files
differ from the archived checkout), and **all 16 tests pass against it
unmodified.** They were never fork regressions and never upstream
regressions — they were stale-gold artifacts of gating against a dead
suite. The archived checkout is retired as a gate.

Both compilers were then run over the full vendored suite (3101 tests vs
the archived suite's 2559). Definitive numbers, recorded in
`docs/conformance/ivtest_vendored_baseline_2026-07-18.txt` (full name
lists in that file):

| Run | Failed | Passed | NI | EF |
|-----|--------|--------|----|----|
| fork | **110** | 2983 | 5 | 3 |
| upstream 13.0 @ 9b44d55 | **83** | 3010 | 5 | 3 |

- **31 common failures** — genuinely pre-existing upstream.
- **52 upstream-only failures** — tests the **fork fixes** (the
  `sv_assoc_*`/`sv_class_*`/`sv_queue_*`/`sv_virtual_*` runtime tests for
  features the fork implemented, plus the two `sv_mailbox_*` tests below).
- **79 fork-only failures** — the corrected fork-regression frontier.
  Initial triage splits them into: (a) a large block of `*_fail*` **CE
  tests silently accepted** — `sv_darray_assign_fail1–6`,
  `sv_queue_assign_fail1–6`, `enum_compatibility_fail2–8`,
  `task_nonansi_*2`, `sv_import_hier_fail*`, `sv_ps_hier_fail*`,
  `sv_timeunit_prec_fail*`, `sv_deferred_assert/assume*`, etc. — the
  manifesto's core "loud rejection" obligation, now measurably violated
  on the live suite; (b) **parser regressions** on newer test shapes:
  module-level `C c = new;` (`sv_class_constructor1` and much of the
  `sv_class_*` block — the fork's gate-instantiation reinterpretation
  errors with "Invalid module instantiation") and non-ANSI directions
  after variable declarations (`task_nonansi_int2`: `int x; input x;` →
  "Malformed statement", the same declaration-section-exit family as
  Part 8 item 8); (c) known carryovers already root-caused on the old
  suite (`recursive_task`, `case_unique`, `constfunc8`,
  `array_lval_select3a`, `pr243`, `pr987`, `pr1862744b`, `pr2792883`,
  br1005/br_ml/br_gh leniencies).

Suite-integrity repair found along the way: the fork-authored
`sv_mailbox_blocking_peek1`/`sv_mailbox_try_int1` had **malformed
`regress-sv.list` entries** (missing flags/directory columns), reporting
"missing source file" on every compiler, and printed `PASS` instead of
the harness-required `PASSED`. Both repaired; both now pass on the fork
(and fail on upstream — no mailbox support — so they count to the
fork-fixes column).

Some cross-suite categories shift with current golds: e.g. `sv_queue_vec`
now fails for a different, verified reason — the fork **reworded the
queue runtime warnings** ("skipping out of range delete(0) on queue of
size 0" vs gold "skipping delete(0) on empty queue", and one
undefined-index warning is missing entirely), genuine fork diagnostic
drift where the archived suite's complaint had been a stale-gold `'X`
expectation. The archived-suite appendix below is retained as history;
per-test re-verification against the vendored suite happens as each
cluster is worked.

**Gate change (standing):** the ivtest gate is now
`cd ivtest && perl vvp_reg.pl` inside the repo (vendored suite), with
`docs/conformance/ivtest_vendored_baseline_2026-07-18.txt` as the
committed name-diff baseline. UVM sweep, bundled VPI, and negative-suite
gates are unchanged.

## Part 10 — The 79 fork-only vendored failures: 54 fixed (2026-07-18)

Working through the corrected frontier from Part 9, in three gated
batches. Vendored ivtest went 110 → 86 → 56; UVM sweep 187/0/1
(new regression tests included); VPI 81/81; negative 38/38.

**Batch 1 — parser regressions (24 tests).** (a) Module-level
`C c = new;` died in the no-port instantiation shape because
class_new/dynamic_array_new are not derivable from `expression`;
gate_instance gained those initializer alternatives. (b) `c = C::new;`
was unreachable in every expression position — the fork's direct
`TYPE_IDENTIFIER K_SCOPE_RES` expr/lpvalue rules win the LALR shift, so
the class_scope-based class_new path died before `K_new`; expr_primary
now supplies the K_new continuation on the direct prefix. Fixed all 17
`sv_class_*` parse failures. (c) Non-ANSI direction declarations after
the tf_item declaration-section early exit (`int x; input x;`) had no
statement rule; statement_item now routes them into
pform_make_task_ports (top-of-body only, loud error elsewhere) and
PTaskFunc::set_ports merges preserving declaration order — the 8
`task_nonansi_*2`/`task_iotypes` tests.

**Batches 2+3 — strictness restorations and runtime fixes (30 tests).**
- darray/queue assignment compatibility: the parameterized-container
  leniency waved through ANY container-to-container element mismatch;
  now gated to OPAQUE (class/unresolved) element typing, so
  `logic[31:0][] = bit[31:0][]` errors again
  (sv_darray_assign_fail1–6, sv_queue_assign_fail1–6).
- enum implicit cast (6.19.3): literals and RESOLVED integrals
  (array elements, function returns) hard-error again; the
  placeholder-constant leniency survives only for unresolved-call
  NetEConst stubs (enum_compatibility_fail2–8 + br_gh130a, br_gh386c).
- virtual-class `new` (8.21): the silent SV-mode null degrade is gone.
  Hard error outside class scopes (sv_class_virt_new_fail); inside a
  class method the fork's type-parameter collapse can falsely present
  the virtual base (uvm_component_registry#(T)'s `T obj = new`), so
  there it degrades to null WITH a loud warning.
- vvp shallow_copy assert on `d = new [n](q)`: the fork's eager queue
  allocation hands even an empty queue to shallow_copy as a real
  object, and a queue is never the target's concrete class; all six
  shallow_copy flavors now fall back to element-wise copy through the
  virtual get/set interface (sv_darray_copy_empty4).
- queue runtime warning fidelity: empty-queue delete reports
  "skipping delete(N) on empty queue" again (eager allocation had
  routed it to "out of range ... size 0"), and assigning at an
  undefined ('x) index warns loudly instead of the deliberate silent
  skip ("avoid warning spam") the fork had added
  (sv_queue_vec/real/string/parray).
- `{a,b} <= @e v;` and `{a,b} <= #d v;`: the dedicated concat-lvalue
  statement rules only covered the plain `<=` form (nb_ec_concat).
- `reg bool [5:0] v;` in statement context: block_item_decl's
  iverilog-extension rule mirrored into statement_item (constfunc8).
- `wait(0)`: restored upstream's "wait expression is constant false /
  will block permanently" warning, which the fork had deleted (pr987).
  UVM itself contains three `wait(0)`s that now warn — matching what
  upstream prints on the same code.

**Failed attempts, caught by the gates and reverted (recorded so they
are not retried naively):**
1. Excluding literal `new` from the netmisc scalar-stub fallbacks (to
   fix sv_class_new_fail1's `int i = new;`) broke ALL 187 UVM tests:
   UVM's `uvm_default_*_printer = new()` globals lose their class
   typing and arrive at the same fallback statically indistinguishable
   from the test's genuine error. Reverted; sv_class_new_fail1 stays
   failing, blocked on class-typing fidelity, not on a missing check.
2. An unconditional virtual-class-new hard error passed every ivtest
   target but also broke all of UVM (the registry pattern above) —
   replaced with the scope-gated version. A verification lesson is
   recorded with it: the first "clean" compile check measured a
   pipeline's exit status, not the compiler's; gate checks now use the
   compiler's own exit code.

**Remaining 25 fork-only failures, categorized:**
- Policy/feature divergences to document rather than "fix" (11):
  `sv_deferred_assert1/2`, `sv_deferred_assume1/2` (fork implements
  deferred assertions; golds expect the upstream "sorry"), `br1005`,
  `br_ml20150315b`, `br_ml20180227` (intentional SV feature
  leniencies), `case_unique` (fork implements unique-case runtime
  checking, so upstream's "sorry: qualities ignored" is gone),
  `struct_invalid_member` (fork's "`logc` doesn't name a type" is a
  better diagnostic than gold's generic syntax error),
  `sv_class_new_fail1` (see failed attempt 1), `func_empty_arg_fail4`
  (gated on the fork-wide unresolved-reference-as-warning policy).
- Scope-resolution semantics (6): `sv_import_hier_fail1–3`,
  `sv_ps_hier_fail1/2`, `sv_export_fail5` — imported names visible
  through hierarchical/package paths that the LRM says must not be.
- Individual investigations (8): `pr243` (simulation ends one $monitor
  sample early), `string14` (empty-string %s runtime), `pr1862744b`,
  `pr2792883` (hierarchical ref in parameter accepted),
  `array_lval_select3a`, `recursive_task` (blocked on the other
  session's frame refactor), `sv_timeunit_prec_fail1/2`.

## Part 11 — Scope-resolution cluster: 6 more fixed (2026-07-18)

Vendored ivtest 56 → 50; UVM 187/0/1; VPI 81/81; negative 40/40 (two
new tests). The "6-test scope-resolution cluster" turned out to be two
distinct defects, neither of them actually in name RESOLUTION:

1. `sv_import_hier_fail1–3`, `sv_ps_hier_fail1/2`: binding already
   failed correctly — the fork's unresolved-reference-as-warning
   policy then downgraded the error to a compile-progress warning
   (exit 0). Both warning sites in PEIdent elaboration are now gated
   by `unresolved_prefix_is_real_scope()`: a reference that is
   package-scoped (`P::x`) or whose hierarchical prefix names a REAL
   design scope (`m.x`, `inner.x`) takes the hard error — the scope
   exists and the leaf name is genuinely absent (imports are not
   visible through hierarchical or package-scoped paths, IEEE
   1800-2017 26.3); there is no typing-loss excuse. Simple unresolved
   identifiers (UVM's clocking members and macro-collapsed names) keep
   the warning, and the UVM sweep confirms the line holds.

2. `sv_export_fail5`: `export P1::x` validated the wildcard import but
   never PINNED it, so a later local `x` declaration in the same
   package coexisted silently. The export now records the pin in
   explicit_imports and marks it in wildcard_pin_used (an export is a
   genuine use), so the existing add_local_symbol conflict check fires
   the "already imported into this scope" error (26.6).

This also shrinks the func_empty_arg_fail4 policy question: what
remains of the unresolved-reference leniency is only the
simple-identifier case.

Remaining 19 fork-only failures: the 11 policy/documentation items and
8 individual investigations from Part 10, minus nothing — the 6 fixed
here came from the scope-resolution category, which is now closed.

## Appendix — full per-test reason table

Legend: **UNIMPL** = construct not implemented; **LENIENT** = expects a
compile-error the tool doesn't raise; **DIAG-DIFF** = correct rejection,
different message text; **OUTPUT-DIFF** = ran, output differs;
**RUNTIME-BUG** = vvp error/crash; **CRASH** = compiler abort.

The 99 names are exactly those in `base_norm` and reproduce
deterministically on a quiet host.

| # | Test | Category | Definitive reason |
|---|------|----------|-------------------|
| 1 | always_comb_warn | → upstream parity | parse bug FIXED (Part 8 item 8); remaining 6-line diff is a gold-file typo ("Assinging"), identical on upstream |
| 2 | always_ff_warn | → upstream parity | parse bug FIXED; remaining diff is the same gold typo |
| 3 | always_latch_warn | → upstream parity | parse bug FIXED; remaining diff is the same gold typo |
| 4 | analog1 | UNIMPL | Verilog-AMS `V(out)` probe unsupported ("No function named `V`") |
| 5 | analog2 | UNIMPL | Verilog-AMS `<+` contribution → syntax error |
| 6 | array_dump | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 7 | array_lval_select3a | UNIMPL | "sorry: cannot %cassign to word of a variable array" (procedural assign/force to array word) |
| 8 | automatic_events | RUNTIME-BUG | automatic-task locals in edge events → 15× `unresolved vvp_net reference` |
| 9 | automatic_events2 | RUNTIME-BUG | same automatic-var edge-event codegen bug |
| 10 | automatic_events3 | RUNTIME-BUG | same (6× unresolved vvp_net reference) |
| 11 | automatic_task | → **FIXED** | event-after-declaration parser bug fixed (Part 8 item 8); matches gold |
| 12 | automatic_task2 | OUTPUT-DIFF (functional) | `@(array[i])` on automatic-task local never fires → zero output |
| 13 | automatic_task3 | RUNTIME-BUG | automatic-task local in `@(array[j])` → unresolved vvp_net + **segfault** |
| 14 | br1003a | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 15 | br1003b | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 16 | br1003c | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 17 | br1003d | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 18 | br1005 | LENIENT (intentional) | SV queue-in-class now compiles+runs; gold expects `sorry` |
| 19 | br1027a | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 20 | br1027c | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 21 | br1027e | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 22 | br_gh79 | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 23 | br_gh127a | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 24 | br_gh127b | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 25 | br_gh127c | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 26 | br_gh127d | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 27 | br_gh127e | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 28 | br_gh127f | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 29 | br_gh130a | LENIENT | bare int→enum assign accepted (known-open gh#130) |
| 30 | br_gh130b | LENIENT (intentional?) | `enum'(1)` cast accepted; CE variant no longer errors |
| 31 | br_gh157 | DIAG-DIFF/strictness | defparam on localparam now hard-errors vs gold warn+run |
| 32 | br_gh265 | → **FIXED** | was: fork null-fallback codegen replaced elab cast-reject (Part 8 item 10); now matches gold |
| 33 | br_gh315 | UNIMPL/config | `.A` implicit named-port needs SV; normal mode rejects (CE variant OK) |
| 34 | br_gh386c | LENIENT | continuous int→enum assign accepted (known-open gh#386) |
| 35 | br_gh386d | LENIENT (intentional?) | `assign = enum'(1)` cast accepted; CE variant no longer errors |
| 36 | br_gh440 | CRASH → **FIXED** | was: assert abort on `null<=1` (fork leniency leaked width-0 null; Part 8 item 5); now matches gold |
| 37 | br_gh497a | RUNTIME-BUG | packed 2-D `wire[3:0][3:0]` part-select assign → all-`z`, self-check FAILED (known-open gh#497) |
| 38 | br_ml20150315b | LENIENT (intentional) | unpacked struct now accepted; test expects compile error |
| 39 | br_ml20150606 | OUTPUT-DIFF (functional) | port + separate net redecl (`input[3:0] X; wire[3:0] X;`) now "already declared" |
| 40 | br_ml20180227 | LENIENT (intentional) | `reg[127:0]=string` assignment now accepted |
| 41 | br_ml20190814 | OUTPUT-DIFF | extra "SDF WARNING: …TIMINGCHECK not supported" line (specify/SDF, not SV) |
| 42 | case_unique | OUTPUT-DIFF (dropped diag) | "sorry: Case unique/unique0 qualities are ignored" no longer emitted; still PASSED |
| 43 | constfunc8 | UNIMPL | `reg bool [5:0] value;` malformed 2-word type decl rejected |
| 44 | dump_memword | STALE GOLD (archived suite) | fork output identical to upstream; passes the vendored live suite unmodified (Part 9) |
| 45 | fork_join_dis | → **FIXED** | was: `$unm_blk` fork scope hid detached children from `%disable` (Part 8 item 11); passes |
| 46 | fread-error | OUTPUT-DIFF (dropped diag) | `$fread` "first argument must be a reg or memory" error no longer emitted |
| 47 | func_init_var2 | OUTPUT-DIFF (functional) | automatic-fn `automatic int acc=1` initializer ignored in const-fn eval → wrong value |
| 48 | macro_with_args | OUTPUT-DIFF (cosmetic) | macro-arg stringification adds trailing spaces `(a )` vs `(a)` |
| 49 | mod_inst_pkg | → **FIXED** | ANSI-header package import now resolves (bonus from the wildcard-import type-resolution rework, Part 8 item 7) |
| 50 | part_sel_port | OUTPUT-DIFF (pre-existing) | t0 read races multi-driver part-select init propagation; upstream fails identically (re-attributed, Part 8 item 6) |
| 51 | pr1002 | OUTPUT-DIFF (functional) | comb cont-assign lags one delta → stale compare → spurious CHECK FAILED |
| 52 | pr1648365 | OUTPUT-DIFF → **FIXED** | uninit array word read `z` not `x`: eager .array/port resolve skipped init propagation (Part 8 item 4) |
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
| 67 | pr2974294 | OUTPUT-DIFF → **FIXED** | same array-word init-propagation bug as pr1648365 (Part 8 item 4) |
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
| 90 | sv_wildcard_import2 | → **FIXED** | real cause: module-level `typedef_type v = init;` could not parse (Part 8 item 7) |
| 91 | sv_wildcard_import3 | → **FIXED** | same typedef-initializer parse defect (Part 8 item 7) |
| 92 | sv_wildcard_import4 | → **FIXED** | probe-pinning removed; declare-after-use error restored, matches gold (Part 8 item 7) |
| 93 | sv_wildcard_import5 | → **FIXED** | probe silenced; ambiguity reported once via the reference path, matches gold (Part 8 item 7) |
| 94 | task_iotypes | UNIMPL | legacy split task-port typing rejected |
| 95 | uwire_fail | DIAG-DIFF | correct reject; `Unresolved wire 'two'` vs gold `Unresolved net/uwire two` |
| 96 | vcd-dup | OUTPUT-DIFF (cosmetic) | same extra VCD parameter-dump block |
| 97 | vhdl_fa4_test4 | UNIMPL | vhdlpp: generics not bound / "Dimensions must be constant" |
| 98 | vhdl_inout | UNIMPL | vhdlpp inout continuous-assign strength restriction |
| 99 | vhdl_multidim_array | UNIMPL | vhdlpp multidim array in generate: "Scope index not constant" |

*(Per-batch source tables from the five root-cause passes are retained in
the session scratchpad under `findings/`.)*
