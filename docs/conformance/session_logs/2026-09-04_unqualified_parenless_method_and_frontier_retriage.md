# 2026-09-04 — Unqualified paren-less method calls, and a re-triage of the uvm/runtime frontier

Branch: `agent/string-array-param-after253-arm64-20260904` (PR #254)

## 1. Frontier re-derived from census data, not from the previous log's narrative

Starting point: the seed-propagation census
(`evidence/opentitan-seedprop-after253-arm64-20260904`), PASS 195, DEBT 33.

Aggregating the **uvm** and **runtime** lanes by first diagnostic gave 49 of 82
FAIL rows as bare `syntax error` — apparently the dominant family. Resolving
each to its source construct dissolved it into three unrelated categories, and
**the two largest were not compiler gaps**:

| Category | Cores | Verdict |
|---|---|---|
| `static task host();` at module/program scope | 4 | **Upstream-invalid** — IEEE 1800-2017 A.2.6 puts `lifetime` *after* the keyword (`task static host()`); a leading `static` is legal only as a class `method_qualifier` (A.1.9). slang rejects it too. |
| `import pkg::item;` in a class body | 2 | **Upstream-invalid** — already recorded. |
| Undefined macros (`RNG_BUS_WIDTH`, `SRAM_TYPE`, `INSTR_EXEC`, …) | 6 | **Census harness gap** — per-core dvsim `build_opts` defines are not extracted. A `warning: macro X undefined (and assumed null)` precedes the syntax error in `matrix-compile.log`. |

The durable lesson is recorded as a memory: check the IEEE BNF and slang on a
four-line reducer *before* writing grammar code. Core count measures how often
OpenTitan writes a construct, not whether it is legal.

## 2. The real frontier is the DEBT set, and it is the xbar family

`DEBT` is decided by `setup_findings or semantic_debt` being non-empty
(`opentitan_matrix.py`), so enumerating `semantic_debt` per row is complete for
the uvm lane. Doing that showed:

- **All 27** uvm/runtime DEBT rows carry the ref-formal queue mechanism.
- No row is one mechanism from PASS; the minimum is three.
- **16 rows (8 cores × 2 lanes) are the xbar family**, each with exactly three
  mechanisms: unresolved `get_full_name`, an untranslated constraint, and the
  ref-formal warning.

That makes the xbar three-set the correct unit of work.

## 3. Fixed: unqualified paren-less zero-argument method call (IEEE 13.4.2)

`xbar_base_vseq.sv:68-70` writes `` `uvm_info(get_full_name, …) `` — a bare
identifier naming a zero-argument method inherited from `uvm_object`.

This was **silent and wrong, not merely unsupported**: the reference failed
signal binding, elaborated to nothing, and the read yielded an empty string.
The only diagnostic was a compile-progress warning.

Fix: `paren_less_class_method_call_()` in `elab_expr.cc`, called from **both**
binding-failure paths. It runs only after ordinary signal binding has failed,
so it cannot shadow a real signal.

Two details that mattered:

- **The argument count must discount the implicit `this`.** A non-static class
  method carries the synthetic `THIS_TOKEN` (`"@"`) port ahead of its declared
  arguments, so a zero-argument method has `port_count() == 1`; a *static* one
  has no `this` and gives `0`. Discounted the way `elab_sig.cc:1292` does.
  Testing `port_count() != 0` makes the guard never fire; `<= 1` would wrongly
  resolve one-argument methods.
- `func_def()` may be null before a signature is published — skip, don't guess.

### Why this took five rebuild cycles in an earlier session

The prior attempt placed a probe immediately before the
`Unable to bind wire/reg/memory` warning; the probe never executed while the
warning did, and the cause was never found.

**There are two emitters of that message in `elab_expr.cc`, and the one that
fires is the earlier, deeper-nested one.** `grep` for the full phrase finds
only one site because at the other the string is split across a line break:

```cpp
cerr << ... ": warning: Unable to bind "
     << "wire/reg/memory `" << path_ ...
```

Separately: `driver/iverilog` invokes the **installed** `local-install/lib/ivl/ivl`,
so `make` alone does not put a change in front of the driver — `make install`
is required. That, not env-var propagation, is why probes appeared not to fire.

### Verification

- New paired regression `sv_class_parenless_unqualified_method` (2017/2023),
  covering the inherited case, a **static** method (no implicit `this`, the
  other side of the port-count branch), explicit parentheses, a one-argument
  method that must *not* resolve paren-less, and a same-named local variable
  that must still win. slang 11.0.448: 0 errors, 0 warnings.
- Real core recompiled (working rule 7): `top_darjeeling_xbar_dbg_sim` drops
  from 6 debt lines to 3 — all three `get_full_name` lines gone.
- All 8 xbar cores carry `get_full_name` as their **only** unresolved name, so
  the mechanism is fully cleared for the whole family.

## 4. The ref-formal warning: re-classified, then fixed

Checked before writing code, and the answer changed the plan:

- The callee `glitch_shadowed_reset` **never writes** the queue formal — it
  only reads it.
- The call site is a plain `fork…join`, so IEEE §16150 (ref arguments in
  `join_any`/`join_none`) does not apply.
- The warning nonetheless fires because its gate is
  `task_body->contains_detached_fork()`, and the callee body *does* contain one
  through a macro expansion (`DV_SPINWAIT`).

Value-copy has **two** hazards, and the warning names only the first. The
second is the mirror image: `t-dll.cc:3575` binds a container `ref` formal as
`IVL_SIP_INOUT`, so even a read-only callee copies *out* at return — if the
caller mutates the actual concurrently (here a sibling `fork` branch runs
`run_csr_vseq`), the stale copy-out silently clobbers it. **A read-only callee
is therefore necessary but not sufficient** for the deviation to be
unobservable, so simply suppressing the warning would be unsound.

`peek_lref()` looked like a cheap read-only test but is unusable: the
diagnostic is emitted during *signal* elaboration (`elab_sig.cc:3081`), before
any statement is elaborated, and it would under-count queue mutations such as
`push_back`. Deferred deliberately rather than rushed.

## 5. Remaining xbar mechanisms

- **Constraint, nested indexed foreach target.** `elaborate.cc` bails
  explicitly on `cfe->has_hierarchical_target()`. The comment is right to: the
  array (`xbar_devices`) is package-scope, not a rand property, and falling
  through to the single-level lookup would silently iterate the *wrong* array.
  Needs hierarchical path storage plus package-scope resolution in the
  constraint IR.
- **Ref formal**, as above.

Neither clears a row alone — every xbar core needs all three.

## 6. Recorded, not chased: unresolved `i` in a constraint foreach

18 occurrences across i2c_sim and the two `*_chip_sim` cores, reported as
`Unable to bind wire/reg/memory `i''. The reported line is a blank line at the
end of a task -- a macro-expansion artifact. The real construct is inside
`DV_CHECK_RANDOMIZE_WITH_FATAL`, e.g. `spi_host_seq.sv`:

```systemverilog
foreach (data[i]) {
  data[i] == local::data[i];
}
```

The gap is that the constraint `foreach` loop variable is not bound when
resolving an index inside a `local::`-qualified reference (IEEE 1800-2017
18.7.1, `local::` scope resolution inside `randomize() with`). Not chased:
the affected cores carry other blockers, so clearing it alone moves nothing.

## 7. Ref-formal: clause verified and blast radius measured

Recorded here because an earlier note cited "IEEE 1800-2023 ~line 16150", which
is a LINE number, not a clause. The actual citation is **IEEE 1800-2017 9.3.2
(Parallel blocks)**, identically worded in 1800-2023 except for an added
`ref static` exception:

> Within a fork-join_any or fork-join_none block, it shall be illegal to refer
> to formal arguments passed by reference other than in the initialization
> value expressions of variables declared in a block_item_declaration of the
> fork[, unless the argument is declared ref static].

Note the exception the earlier note omitted: a reference IS legal in the
initialization value expression of a fork-local variable.

Blast radius, measured before implementing: the warning has exactly **one**
site in the entire corpus -- `shadowed_csr` in `glitch_shadowed_reset` -- with
71 occurrences across 17 cores. In that task the formal is referenced only in a
plain `foreach` at lines 228-233; there are no literal fork/join tokens, and
the sole detached fork comes from `DV_SPINWAIT` (which expands to nested
`fork ... join_any` via `DV_SPINWAIT_EXIT`) whose arguments do not mention the
formal.

So narrowing the gate to "the formal is referenced inside a detached fork
subtree" clears all 71 lines, and the error branch is **dead code on this
corpus** -- no core can move backward.

### Implemented

Gate changed from `task_body->contains_detached_fork()` to
`task_body->detached_fork_refs_name(port->name())`, backed by two pform
virtuals:

- `Statement::refs_name(perm_string)` -- default **true**, overridden in ~20
  kinds; `PExpr::refs_name(perm_string)` -- default **true**, overridden in 12.
- `Statement::detached_fork_refs_name(perm_string)` -- default **false**,
  overridden in exactly the kinds that override `contains_detached_fork()`, so
  it locates detached forks as completely as that already-trusted walk.

The polarity is the entire safety argument: an unmodelled node kind answers
"referenced", so the diagnostic is retained. A missing override costs
precision, never soundness.

The message now cites 9.3.2 and says the construct is illegal, rather than
describing only the lost-write symptom.

Verified: `top_darjeeling_xbar_dbg_sim` drops from 3 debt lines to **1** (the
constraint alone). slang agrees in both directions -- it rejects the illegal
shape with `-Wref-arg-in-fork-join` and accepts the legal one with 0 warnings.

Two paired regressions: `sv_ref_queue_formal_unrelated_fork` (legal shape must
stay quiet, and writes through the reference must still reach the caller) and
`sv_ref_queue_formal_fork_illegal_warn` (the 9.3.2 violation). The second one's
gold is a live demonstration rather than a text pin -- it prints
`caller sees size 1 (the branch's write is lost)`. Writing it exposed a first
draft where the branch finished BEFORE the task returned, so the copy-out
captured the write and nothing was lost; the delays had to be inverted to make
the hazard real.

## 8. The constraint frontier is five mechanisms, not one

Aggregating by message makes "constraint `X' could not be translated" look
like a single family (42 occurrences, 15 cores). Decomposing by the actual
constraint TEXT shows five unrelated mechanisms, in rising order of cost:

| Shape | Occ | Nature |
|---|---|---|
| `(value) <= ($clog2(RxFifoDepth))` (uart_base_vseq.sv:109-110) | 4 | A constant system function -- see below. Cheapest of the set. |
| `(num_lanes) == (cfg.get_sio_size())`, `...idcode.get_n_bits()`, `(m_data_pkt.data.size()) == (num_of_bytes)` | 8 | A method call on a NON-RANDOM state object. Needs solve-time evaluation of an arbitrary state expression -- the general feature the `delem`/`qmelem` nodes only do for properties. |
| `foreach (data_q[...])` (spi_host_tpm_seq.sv:60) | 4 | A second foreach shape. |
| kmac `local::`-qualified compounds | 8 | Mixed; not yet decomposed. |
| `if (use_last_item_addr) { ... } else { ... }` (xbar_tl_host_seq.sv:46) | 20 | The hierarchical `foreach` target -- `elaborate.cc` bails deliberately on `has_hierarchical_target()`. Needs hierarchical path storage plus package-scope resolution in the constraint IR. Most expensive, and the last xbar blocker. |

The same lesson as section 1 applies: the message is not the mechanism.

### The `$clog2` case is a silent wrong answer, and it is general

Reduced, it is not about parameters or even about randomization:

```systemverilog
class it;  rand int unsigned v;  constraint c { v <= $clog2(64); }  endclass
class it2; rand int unsigned v;  constraint c { v <= $bits(int); }  endclass
```

Both constraints are DROPPED -- `warning: Constraint item ... is not
representable in the constraint solver and is ignored` -- and both variables
come back completely unconstrained (observed 2915189536 and 3905576338 against
bounds of 6 and 32). A LITERAL argument fails, so this is not a missing
constant-fold of a parameter reference: the constraint IR converter handles no
constant system function at all.

This is the same defect class as the `get_full_name` one fixed in this branch:
a "compile-progress" warning standing in front of a silently wrong answer
rather than an unsupported-but-safe fallback. The fix direction is to evaluate
an elaboration-time-constant sub-expression and emit it as an IR literal, which
covers `$clog2`, `$bits` and the rest at once.

## 9. Constant $clog2 constraints and review corrections

IEEE 1800-2017 and IEEE 1800-2023 **20.8.1** require an arbitrary-width
integral argument interpreted as unsigned, with zero producing zero.
`uart_base_vseq.sv:109-110` uses `value <= $clog2(RxFifoDepth)` and a related
minus-one bound. Before this increment, the converter dropped these constraint
items with a warning; the reduced `v <= $clog2(64)` produced `v=2915189536`.

The converter now obtains the full `verinum` for integral numeric literals,
unary +/- numeric literals, and simple named integral constants, including
direct package constants. It calls the existing `NetESFunc` evaluator before
encoding the result in the constraint IR. It does not implement another
logarithm algorithm. Unknown, runtime, cast, composite, qualified-class and
foreach-context arguments retain the existing unsupported handling. A failed
fold falls through; it does not intercept unrelated system functions.

Constant lookup preserves target-object precedence, `local::` and explicit
inline identifier lists (**18.7.1**, both editions), array-method iterator
shadowing (**7.12**), and nearest-declaration lookup (**23.9**). A declaration
that is not an integral constant stops the search. Hierarchical references
outside the new bounded fold use the existing `symbol_search` resolver, so
`main.N` retains its prefix rather than becoming an unrelated bare `N`.

### Review findings and their disposition

Fresh agent review, a user-authorized Claude Code CLI review, and a final
bounded fresh review found concrete defects in intermediate drafts:

- The original 64-bit fold returned 0 for `128'h10000000000000000`; full-width
  evaluation returns 64. A 128-bit package parameter also checks a non-power
  value whose result is 65.
- The shared evaluator incorrectly applied an integer-width floor to sized
  negative operands. It now preserves the operand's declared bits:
  `8'shff` gives 8, `1'sb1` gives 0, and `16'sh8000` gives 15. Unary signed
  literals and runtime signed variables are checked against ordinary folding.
- Re-elaborating the whole call in caller scope misbound target parameters and
  enums. Tests cover the target, `local::`, an explicit `with(v)` list, and a
  non-default specialization.
- With clauses, named arguments, real/string casts, unknown values, and
  iterator/class-member shadowing could be silently accepted or misbound.
  Negative tests pin the diagnostics. Nearer nonintegral parameters, variables,
  functions and events stop the constant search.
- Over-restricting the shared helper lost a genuine hierarchical constant.
  A runtime assertion now retains `main.N` through `symbol_search`.

The existing `clog2.v` had two stale expectations of 32 for
`$clog2(-(2**31))`. The direct argument is 32 bits, `80000000`; interpreted as
unsigned under **20.8.1**, it is exactly 2**31 and the answer is 31. Both
assertions now require 31. The recorded reducer also reports
`$clog2($unsigned(-(2**31))) == 31`, including strict expression-width mode.
An unsized *parameter* can have a different width under Icarus's existing
extension; that behavior is not conflated with the direct expression.

Earlier drafts also used `need_const=true`, which introduced hidden
elaboration errors, and returned early for all unhandled system calls, which
made unrelated `std::randomize() with` calls fail. Both approaches were
rejected. Every elaboration revision is checked against the real UART core.

### Regressions and evidence

`sv_constraint_const_sysfunc_clog2` repeatedly enforces the [3,6] and [0,5]
bands, checks exact edge values and lookup, and exercises the ordinary/runtime
signed-value path. `sv_constraint_clog2_unsupported` checks diagnostics for
unsupported and invalid inputs. Both have 2017/2023 legacy and JSON entries.
Slang is an independent parser/elaborator comparison; the local IEEE texts
remain normative.

Evidence is under
`evidence/clog2-xbar-codex-arm64-20260904/` at workspace level. It includes
review artifacts, the Claude CLI result and reconciliation, reducers, build
logs, focused results, gate markers and application comparisons. Copyrighted
LRM text remains untracked. The originally inherited gate 4 completed, but
its results do not validate the subsequent review changes; the checkpoint
requires a fresh full gate and per-core censuses.

## 10. Note on predicted movement

The 8 xbar cores appear in both lanes with identical debt, but the lanes do not
share a PASS criterion. Clearing compile debt makes the **uvm** rows PASS; the
**runtime** rows will then attempt execution for the first time and may land in
RUNTIME_FAIL or RUNTIME_TIMEOUT. No core count will be claimed before the
per-core census diff says so.

## 11. Reviewed $clog2 checkpoint validation

Native ARM64, Homebrew Bison 3.8.2, `make -j1 && make install`, absolute
worktree `local-install/bin` first on PATH, and the 45-second CPU guard:

| Check | Measured result |
|---|---|
| Focused legacy (including existing clog2 tests) | 6/6 |
| Focused JSON, both editions | 4/4 |
| Full legacy | 4537/4542, 0 failed, 2 NI, 3 EF |
| Name-diff gate | Clean, 0 unexplained |
| Full JSON/VVP | 1431 tests, 0 failed |
| VPI | 103/103 |
| Negative suite | 149 passed, 0 failed |
| Malformed-bytecode/runtime invariants | Pass |
| UVM with real DPI | 355 passed, 0 failed, 0 skipped |

Completion markers: `gate-checkpoint.log` contains
`CLOG2_CHECKPOINT_GATE_DONE` and `CLOG2_CHECKPOINT_GATE_EXIT=0`;
`json-checkpoint.log` contains `JSON_CHECKPOINT_GATE_EXIT=0`. Full UVM
output is `uvm-checkpoint.log`. These are under the evidence directory in
section 9. The UART checkpoint replay compiles with the same two remaining
port/driver diagnostics; the constraint warnings are absent.

Commands are preserved in `run-checkpoint-gate.sh`; it runs the focused
legacy/JSON lists, `.github/ivtest_gate.sh`, and `.github/uvm_test.sh`.
The full JSON run is `python3 vvp_reg.py` from `ivtest`, after the legacy
sweep finishes. `checkpoint-build.json` records the installed engine/runtime
hashes. Application-level claims await the following per-core censuses.

## 12. Authorized Caliptra re-census at 1819a3ee5

All 105 job classifications and all three tool-mode diagnostic/exit-code
comparisons are unchanged from
`caliptra-constraint-after253-arm64-20260904/caliptra-static-census.json`.
The measured result remains **52 PASS, ICARUS_GAP 0**, with 1 DEBT,
51 SHARED_SOURCE_OR_CONFIG and 1 SOURCE_ORDER_DEBT. No added/removed jobs,
new warnings/errors, changed diagnostics, input changes or timeouts. This is
the static fileset census, not a claim of full DV runtime completion.

Caliptra revision `bd31614182fb56e55578f48086a10ded650434fd` and Adams Bridge
`e59eba955eac2a1adcb059f250641ede78e304be` are unchanged; the checkout is
clean. Compile YAML, compile specs, RTL filelist and fileset-top hashes match
the baseline. The copied evidence harness changes only its output location,
operational limits and stale descriptive text: the final re-census applies
the user-authorized 300-second CPU guard and 300-second wall timeout, removes
the previous output-size cap and uses 3 workers.
The prior run used a 190-second CPU limit, a 32 MiB output cap and 4 workers;
no command times out under the current limits. Slang 11.0.448 remains an
independent comparison.

Result: workspace
`evidence/caliptra-clog2-300s-after253-arm64-20260904/caliptra-static-census.json`.
Per-job comparison: `evidence/clog2-xbar-codex-arm64-20260904/caliptra-300s-diff.json`.
The run log contains `CALIPTRA_CLOG2_300S_DONE=0`. The comparison also checks
per-mode error/warning totals and diagnostics, so unchanged totals alone
are not the basis of the no-regression finding.

## 13. Five-minute guard update

The user explicitly changed the per-process CPU guard to 300 seconds on
September 4. The shared ARM64 resource runner and current execution guidance
now use that limit. Section 11's complete local gates passed under the previous
45-second limit and remain valid; their evidence has not been rewritten.

The first OpenTitan checkpoint census inherited the 45-second limit in its
Python coordinator as well as its children. The coordinator exhausted that
limit after saving 505 of 530 rows. Its partial report and the interrupted
remaining-row replay are retained as historical evidence, not a complete
comparison. New OpenTitan and Caliptra censuses use separate `clog2-300s`
evidence directories and the unchanged installed `1819a3ee5` binaries.
`checkpoint-300s-census-build.json` verifies both binary hashes and the
shared runner's actual CPU limit of 300.

## 14. Complete OpenTitan checkpoint census and per-core comparison

The 300-second census completed all 530 rows on installed compiler
`1819a3ee5`. Its completion marker is `CLOG2_300S_CENSUS_DONE=1`: the exit
status reflects the existing unsuccessful rows, not an interrupted census.
All 530 classifications match the refformal baseline, with no added/removed
rows and no lost PASS row:

| Status | Before and after |
|---|---:|
| PASS | 195 |
| DEPENDENCY_ONLY | 157 |
| UPSTREAM_INVALID | 39 |
| FAIL | 84 |
| DEBT | 33 |
| SETUP_FAIL | 6 |
| RUNTIME_FAIL | 15 |
| RUNTIME_TIMEOUT | 1 |

The summed `semantic_debt_count` changes from **2250 to 2245**. The complete
per-core count changes are:

| Core / lane | Before | After | Classification |
|---|---:|---:|---|
| uart_sim / uvm | 4 | 2 | DEBT |
| uart_sim / runtime | 4 | 2 | RUNTIME_FAIL |
| darjeeling rstmgr_sim / uvm and runtime, each | 2 | 1 | UPSTREAM_INVALID |
| earlgrey rstmgr_sim / uvm and runtime, each | 2 | 1 | UPSTREAM_INVALID |
| entropy_src_sim / uvm | 124 | 126 | FAIL |
| entropy_src_sim / runtime | 126 | 127 | FAIL |

The actual removed diagnostics are eight constraint warnings: two UART
`$clog2` bounds per lane, and one rstmgr `start_reset_c` warning per lane and
top variant. Entropy's apparent increase is an interleaved-output counting
artifact. Each of its four raw logs contains the identical 127 undefined
macro warnings (123 RNG_BUS_WIDTH, 2 DISTR_FIFO_DEPTH and 2
RNG_BUS_BIT_SEL_WIDTH), 119 error tokens and compiler return code 239.
Preprocessor warnings interleave with compiler messages, changing how many
lines match the existing census patterns. AES also has differently merged
warning lines with identical macro-message multisets and unchanged counts.
No classifier or baseline was changed to hide this variation.

The comparison reads complete compile logs, not the truncated stored
`semantic_debt` lists. Runtime return codes, timeout flags, error/debt counts
and pass-banner results are all unchanged. Timing varies and is not a pass
criterion. The corpus revision, target inventory/configuration hashes and
FuseSoC inputs match; installed compiler/runtime hashes were checked before
and after the run. OpenTitan, Caliptra and Adams Bridge sources remain
unmodified. There are no observed classification or semantic regressions
in this checkpoint, and no new core PASS claim.

Evidence, relative to workspace `evidence/`:

- `opentitan-clog2-300s-after253-arm64-20260904/opentitan-matrix.json` and `.md`
- `clog2-xbar-codex-arm64-20260904/opentitan-300s-diff.json`
- `clog2-xbar-codex-arm64-20260904/opentitan-300s-raw-diagnostic-diff.json`
- `clog2-xbar-codex-arm64-20260904/macro-diagnostic-interleaving-proof.json`
- `clog2-xbar-codex-arm64-20260904/opentitan-300s-input-check.json`

Exact run commands are preserved in `run-opentitan-300s-census.sh` and
`run-caliptra-300s-census.sh` in that evidence directory. Per-core comparison:
`python3 compare-censuses.py BEFORE_JSON AFTER_JSON OUTPUT_JSON`.

GitHub records PR #254 merged by dsellerbrock at 2026-09-04 20:55:21 UTC,
as `bafc8b5b4`; this agent did not merge it. The canonical main checkout and
shared code graph were updated. All old worktrees are retained. The next
branch starts from that merged main; the hierarchical foreach implementation
is still pending. A fresh design review and a failing signed-index reducer
are recorded in `xbar-design-review.md` and `foreach-index-signed-red.sv` in
the evidence directory.
