# 2026-07-15 — M8 tail close-out (PR #76)

Directive: "Okay finish the M8 tail first to fill close out then move
on to M9." PR #75 (M4 close-out + M8 increment 2 core) merged earlier
today; this session closes the recorded M8 tail on a fresh branch
from the merged main.

## T1 — vif.cb.out buffered drives (14.16 + 25.9)

The canonical UVM driver pattern `@(vif.cb); vif.cb.out <= v;` now
rides the buffered-drive machinery through class handles:

- `_ivl_obuf$` / `_ivl_opend$` registered as interface-class
  properties; the runtime resolves them by name in the bound
  instance scope, where the instance's apply process (from PR #75)
  lands buffered drives at each clocking event.
- New `%vif/tickchg <M>` opcode
  (`vvp_vinterface::sig_changed_this_step`): pops a vif handle,
  answers "did the M-th property signal (the sampler tick) change
  this time step" via the preponed-vs-current comparison — the
  did-the-event-occur test through a class handle. Nil/non-vif
  handles answer no (buffer), the safe arm. Lowered from the
  `$ivl_vif_tick_changed(vif, M)` sfunc.
- `elaborate_clocking_output_drive_` shape (c): class-typed prefixes
  (`vif.cb.out`, `cfg.vif.cb.out` chains walked through properties)
  assemble the transform from re-elaborated property paths: obuf
  property store; tickchg conditional; drive-now NBA property store
  vs opend mark. Output skews through a vif are not applied (the
  class side carries no skew info; recorded).

Test: tests/m8_vif_clocking_drive_test.sv.

## T2 — global clocking + $global_clock (14.14, G59 FIXED)

`global clocking [id] @(event); endclocking` parses (new K_global
rules, bison conflict counts unchanged at 458/1053) and registers per
module with one-per-scope and no-items checks (both diagnosed).
`@($global_clock)` resolves the nearest enclosing module's global
clocking by scope walk and elaborates the wait in the DEFINING
module's scope — plain event-signal names do not cross
module-instance boundaries, which the first cut got wrong (the
submodule probe caught it).

Tests: tests/m8_global_clocking_test.sv (including the strict
same-step @(cb)-after-raw-wake sample pinning), negative
m8_global_clocking_items.sv.

## T3 — clocking_decl_assign (A.6.11)

`input a = hier.sig;` declares a clockvar sampling a hierarchical
signal. PClocking::decl_assigns carries the expression;
resolve_clocking_raw_signal (netmisc.cc) resolves the sampled raw —
the local same-name signal, or the decl_assign target via
symbol_search (signal-path shape; other expression shapes and output
decl_assign are diagnosed sorries). The elab_sig creation pass and
both sampler loops route through the resolver, so decl_assign
clockvars get the full #1step machinery, read-rewrites, and 14.3
write enforcement for free.

## T4 — scalar `x <= ##N v` (14.16)

The no-prefix form now lowers at parse to a repeat-event drive on the
`$ivl_default_clock` marker, resolved at elaboration to the enclosing
scope's DEFAULT clocking block (14.12) — preferring its sampler
trigger (so landings order after that edge's input sampling), falling
back to the raw event elaborated in the defining scope. The
$global_clock elaboration branch was generalized to serve both
markers and itself gained the trigger-redirect preference (inert for
item-less global blocks, live if one ever gains a sampler).

Test: tests/m8_decl_assign_test.sv covers T3 + T4.

## T5 — diagnostics for the remaining corners

- Edge-qualified skews (`input negedge #1step s`): the delay/#1step
  part is honored; the edge qualifier is now a DIAGNOSED sorry at
  elaborate_sig instead of silently recorded (g01's skew-form block
  exercises it).
- Already diagnosed from PR #75: real/string/array clocking signals
  (alias + sorry), unresolvable decl_assign shapes, output
  decl_assign, non-clockvar `<= ##N` l-values (now only non-PEIdent
  l-values).

## M8 disposition

With this PR, M8 (clocking blocks and program scheduling) is CLOSED:
input sampling (#1step Preponed + numeric skews at Observed), output
drives (buffered, skewed, cycle-delayed, through all three access
paths including virtual interfaces), @(cb)/@(vif.cb)/##N/default/
global clocking event semantics, and 14.3 direction enforcement.
Remaining corners are all explicitly diagnosed, never silent:
edge-qualified skew application, real/string/array clockvars, output
decl_assign, vif output skew values, force-vs-history interaction.

Next: M9 (core SVA engine, G05/G06).

## Evidence

Recorded in the promotion note below after the full sweeps.

## Promotion evidence (T1–T5)

- UVM harness: **145 passed / 0 failed / 0 skipped, zero "(no-check)"
  entries** (142 at PR #75 merge + m8_vif_clocking_drive_test,
  m8_global_clocking_test, m8_decl_assign_test).
- ivtest (shim PATH): Total=2559 Passed=2456 Failed=100 — failure
  names identical to fails_baseline.txt except `pow_ca_signed`, the
  documented load-timeout flake (verified standalone: PASSED).
- Negative suite 13/13; focused clocking battery 12/12.

The M8-tail WIP commits are hereby promoted — regression-clean.
**M8 (clocking blocks and program scheduling) is CLOSED.**

## M9 entry reconnaissance (done this session, read-only)

Today's `assert property` support is a parse-time lowering (parse.y
~2416): `[@(clk)] [disable iff (e)] A [|-> / |=>] B` becomes an
always block with LIVE (unsampled) expression evaluation, `|=>`
APPROXIMATED as `|->`, no sequence operators, and `$past` stubbed.
property_expr admits only plain expressions around the implication.

M9 increment 1 plan (G05/G06):
1. Sampled evaluation: assertion expressions read Preponed values —
   the M8 `%hist/on`/`%load/preponed` machinery, with checking moved
   past the NBA region (`%wait/observed`).
2. Correct `|=>`: 1-cycle antecedent pipeline (sampled).
3. `##N` / `##[m:n]` sequence delays in consequents via bounded
   cycle counters (per-attempt threads).
4. `$rose/$fell/$stable/$past` on the sampled-value history.
5. Named `property`/`sequence` declarations (parse + instantiate).
6. Honest sorries for the remaining sequence algebra (repetition,
   throughout, intersect, first_match) instead of silent acceptance.
