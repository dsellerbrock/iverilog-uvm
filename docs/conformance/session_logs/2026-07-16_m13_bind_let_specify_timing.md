# 2026-07-16 — M13: bind, let, specify timing checks, rare constructs (PR #76)

Directive: "Fully implement M13 in this session until complete —
complete and full implementation, all iterations in this session."

M13 is the "language-completeness tail" milestone: the SystemVerilog
constructs a real UVM/gate-level flow still meets that earlier
milestones left as parse-and-drop or gated warnings. The audit at the
start of the milestone established per-construct dispositions
empirically; this log records what each increment turned into real,
observable semantics, and what stays a recorded corner.

## Audit findings (start of M13)

- **bind** (23.11): parsed at module-item level but the instantiation
  was SILENTLY DROPPED; description-level bind was a syntax error.
- **let** (11.13): loud sorry, declaration discarded.
- **timing checks** ($setup/$hold/$width/$period/$recovery/$removal/
  $skew/$setuphold/$recrem): PTimingCheck classes existed but
  elaborate() only aliased delayed signals — violations were NEVER
  reported (a warning with -gspecify, silence without).
- **config** declarations: loud sorry + skip (design still runs).
- **specify path delays**: working.
- **strengths / rare nets** (tri0/tri1/wand/wor/uwire, drive
  strengths): working.
- **preprocessor corners** (stringize `` `" ``, paste ``` `` ```,
  nested macros): working.
- **constant user functions** in localparams, $clog2/$bits: working.
- **trireg**: loud sorry.

## M13-1: bind directives

Replaced the silent-drop grammar actions with real semantics. Bind
directives (both description-level and module-item-level) are
collected during parse into a pending list and applied by
`pform_apply_binds()` from `pform_finish()`, after all source files
are parsed. Each bind appends its bound PGModule instantiation(s) to
the TARGET module's gate list, so every instance of the target
elaborates the bound instance in target scope — exactly the point of
bind: attaching checkers/monitors without editing the design.

Because a bind may be parsed BEFORE its target module (even in a
different file), the bound port/parameter expressions must resolve as
if written at the end of the target body. A new `PExpr` virtual,
`reloc_lexical_pos_bind()`, recursively relocates identifier lexical
positions to end-of-scope so the declaration-before-use check does not
reject target-internal names.

Works: named/positional parameter overrides, connections to
target-internal signals, multiple instances per directive, binds into
interfaces, cross-file / bind-before-target ordering, bound SVA
checker modules. Loud diagnostics: unknown target module, self-bind
recursion, program-block target, bind to a specific hierarchical
instance (recorded corner), bind with a target instance list (recorded
corner). `pform_finish()` now returns its post-parse error count to
`main()` (previously errors raised there never failed the compile).

Recorded corners: bind to a hierarchical instance path
(`bind top.u0 ...`) and bind with an explicit target-instance list
(`bind M : i1, i2 ...`) — both loud sorries.

## M13-2: let declarations

Replaced the let sorry with real expression-macro substitution. Lets
declared directly in module/interface scope are stored on the pform
Module and copied to a NetScope table at scope elaboration;
`NetScope::find_let` walks up lexically but stops at the module
boundary so lets never leak across instance boundaries. A use of a let
(a `name(args)` call or a bare `name` reference) expands by
structurally cloning the let body with formal names replaced by clones
of the actual argument expressions, then elaborating the substituted
expression in the scope of the use. Expansions are cached per use
node; nested let calls expand recursively behind a depth guard that
diagnoses runaway (self-recursive) lets.

Works: multi-argument lets, argless lets, default and named
arguments, lets calling other lets, bit/part-selects and array-word
selects on formals (grafted onto simple-identifier actuals),
package/hierarchical names and function calls in bodies, use in
procedural / continuous-assign / constant contexts. Loud diagnostics:
arity mismatch, unknown port name, positional-after-named,
typed/ranged let ports (recorded corner), non-clonable expression
shapes, recursion, lets outside direct module scope (recorded corner).

Recorded corners: typed/ranged let ports; lets declared in generate
or other non-module-direct scopes; actual arguments that are not
simple identifiers when the formal carries a select tail.

## M13-3: timing checks

Replaced the warn-and-drop timing-check actions with parse-time
synthesis of checker processes — the same construction strategy as the
M8 clocking and M9 SVA engines. Each check gets a synthesized realtime
timestamp variable updated on its timestamp event; at the timecheck
event the elapsed time is compared against the limit and a violation
is reported with `$display` (`%m`/`%0t`) plus an optional notifier
toggle.

Implemented (active with -gspecify): $setup, $hold, $recovery,
$removal, $skew (violation when the delta EXCEEDS the limit), $period
(against the previous same-edge), $width (opposite-edge, optional
threshold), and $setuphold / $recrem as their paired setup+hold /
recovery+removal checks. The paired checks CLONE their limit
expressions so the originals still flow to PSetupHold/PRecRem for the
existing delayed-signal aliasing. Edge-qualified reference events
(posedge/negedge) and `&&&` conditions are supported.

Consistent with path delays, the whole specify block is inert without
-gspecify (silent — the established opt-in contract, matching how
path delays behave). With -gspecify, unmodeled shapes are loud
sorries: $nochange, $timeskew, $fullskew, edge-descriptor event lists
(`edge [01, ...]`), and $setuphold/$recrem timestamp/timecheck
condition arguments. $width without an edge-qualified reference is a
loud error.

Sampling note: the synthesized checkers observe values at the event
edge, equal to the sampled (Preponed) value for NBA-driven logic —
the same equivalence the M9 SVA engine documents. Blocking-assignment
races against the checked edge are races in event semantics too.

Recorded corners: $nochange, $timeskew, $fullskew (loud sorry with
-gspecify); edge-descriptor event lists; timestamp/timecheck condition
arguments; check-simultaneity fine points (31.4.1) are scheduling
races by construction.

## M13-4: rare constructs pinned; trireg corner

Permanent regression tests lock in the audit's "already correct"
constructs so they stay correct, plus the trireg corner:

- Net-type variety and drive strengths (tri0/tri1/wand/wor/uwire,
  resolved strengths).
- Preprocessor stringize / paste / nested-macro expansion.
- Constant user-function evaluation in localparams (hand-written
  clog2 and $clog2), $bits of a derived width.
- Specify-block module path delays (rise/fall), compiled -gspecify.
- trireg (charge-storage nets — switch-level charge decay, outside
  the verification mission): loud sorry with non-zero exit.

The negative-test runner now accepts `sorry:` as well as `error:` as
a valid loud rejection diagnostic, matching the manifesto's
loud-diagnostic convention for deliberately-unsupported constructs.

Config declarations remain a loud skip (the design compiles and runs
without the config) — a recorded corner, not a hard error.

## Tests

Harness (tests/, CI-run via .github/uvm_test.sh):
- m13_bind_test.sv — description/module-item binds, param overrides,
  internal-signal connections, multi-instance, interface bind, bound
  SVA checker firing on a violation.
- m13_let_test.sv — multi-arg/argless/default/named lets,
  let-calls-let, selects on formals, array-word via formal, parameter
  in body, continuous-assign and procedural use.
- m13_timing_test.sv (-gspecify) — setup/hold/width/period/recovery/
  removal/skew violations each firing once, notifier toggle observed.
- m13_specify_paths_test.sv (-gspecify) — rise/fall path delays.
- m13_rare_constructs_test.sv — strengths, preprocessor, const
  functions.
A per-test IVFLAGS map was added to the harness (mirroring PLUSARGS)
so timing/specify tests compile with -gspecify.

Negative (tests/negative/, run by run_negative.sh):
- m13_bind_unknown_target, m13_bind_self_recursive,
  m13_bind_instance_target, m13_bind_bad_port_ref
- m13_let_recursive, m13_let_bad_args
- m13_trireg_unsupported

## M13 recorded corners (at close)

- bind to a hierarchical instance path / target instance list (loud
  sorry).
- let: typed/ranged ports; lets outside direct module scope; non-
  simple-identifier actuals under a select-tailed formal.
- timing checks: $nochange, $timeskew, $fullskew; edge-descriptor
  event lists; $setuphold/$recrem timestamp/timecheck conditions;
  simultaneity fine points.
- config declarations: loud skip (design runs without the config).
- trireg charge-storage nets (loud sorry).

## Promotion evidence — M13 CLOSED

- UVM harness: **160 passed / 0 failed / 0 skipped, zero "(no-check)"
  entries** (155 baseline + 5 M13 tests).
- ivtest (shim PATH): failure NAMES byte-identical to
  fails_baseline.txt (the two pow_ca_* entries that appeared under
  concurrent-sweep load are the documented ~24s load-time flakes; both
  PASS standalone).
- Negative suite: **21/21**.
- Bundled VPI suite: **79/79** (unaffected — no VPI changes in M13).

The M13 WIP commits (bind, let, timing checks, rare-construct pins)
are hereby promoted — regression-clean.

**M13 (bind, let, configs, specify, timing, rare constructs) is
CLOSED.** The bind directive attaches checkers/monitors to any module
or interface (in-file, cross-file, or before-definition), let
declarations are real expression macros, specify-block timing checks
report violations for real under -gspecify, and every remaining shape
is a loud diagnostic or a recorded corner — never a silent
miscompile. The recorded-corners list above is the M13 follow-up
ledger (same closure pattern as M4/M8–M12).
