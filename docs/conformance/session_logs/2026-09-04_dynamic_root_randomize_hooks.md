# Dynamic root randomize callbacks — 2026-09-04

## Contract and implementation

IEEE 1800-2017 and IEEE 1800-2023 18.6.2 require the virtual built-in
`randomize()` to call the dynamic object's nearest `pre_randomize` and
`post_randomize` declarations. The two callbacks inherit independently.
Their automatic invocation behaves virtually; direct calls retain their
normal nonvirtual method semantics. Clause 18.6.3 suppresses post callbacks
on solver failure. Clauses 18.11/18.11.1 change the set of random variables
for `randomize(null)` without exempting the root object from its callbacks.

The old target implementation chose a static callback or, only if absent,
a unique derived callback. It silently skipped callbacks when siblings each
defined one, and selected a base callback even when a derived override
existed. It also incorrectly suppressed callbacks for checker calls.

The target now emits `%randomize/hook 0` before solving/capturing inline
state and `%randomize/hook 1` after solving. Runtime lookup walks the dynamic
class's actual superclass chain using exact qualified method labels;
suffix fallback is excluded because unrelated packages can use the same
class basename. The existing automatic `%alloc`/function-call trampoline/
`%free` machinery owns each callback frame. The caller re-enters the hook
instruction to free the frame after the call. The receiver remains on its
object stack and the success result remains on its value stack.

This removes the target's callback cache and static/unique-derived
heuristic. It does not change direct method virtual flags, the solver, or
external DV/UVM sources.

## Regressions

`sv_randomize_dynamic_hooks` covers sibling subclasses, independent nearest
inheritance, most-derived dispatch, direct nonvirtual calls, plain and inline
checker calls, failed solves, receiver evaluation once, and package identity.
`sv_randomize_hook_context` covers parameterized classes, pre-callback timing
relative to inline state capture, recursive callback frames, and pre-callback
side effects on successful/failed checker calls. Both are registered in both
harnesses for 2017/2023. Existing receiver and variable-control tests now
expect the clause-required checker callbacks; no test is disabled.

The original sibling reducer fails with all four callback counters zero in
both editions; the dynamic-dispatch regression also fails on the old
installed compiler. All ten new/adjusted direct executions pass on build4. The focused build3
legacy suite passes 38/38. The escaped-name regression was added after that
focused run. Slang accepts the new sources in
both editions as an independent comparison, not a normative oracle.

## Validation

The fresh build4 full gate passed: legacy **4557/4562**, zero failures, two
NI and three EF, with clean name diff; JSON **1451/0**; VPI **103/103**;
negative **149/0**; runtime invariants; real-DPI UVM **355/0/0**.
`root-hooks-final-gate.log` ends `ROOT_HOOKS_GATE_DONE=0`. All compiler binary
fingerprints match the start of the gate. Ten focused 2017/2023 executions
pass, and all three callback reducers also pass with the older synchronous
`IVL_TRAMPOLINE_CALLF=0` path.

The earlier build3 gate was stopped during UVM to repair the review's
escaped-identifier finding and is superseded. OpenTitan and Caliptra censuses
completed sequentially after the final gate, with the same compiler binaries.

OpenTitan's complete 530-row diff is **210 → 203 PASS**, with no input changes.
All RTL, SVA and UVM compile classifications are unchanged. Seven xbar
runtime rows changed from PASS to RUNTIME_FAIL; the eighth changed from
RUNTIME_TIMEOUT to RUNTIME_FAIL. Every candidate xbar reports the same
time-zero `test_seq.randomize()` fatal, zero scoreboard traffic, and a zero
process exit code that the harness correctly refuses to count as PASS.

| Xbar runtime | Previous raw census | Root-callback census |
|---|---|---|
| Darjeeling debug | PASS | RUNTIME_FAIL |
| Darjeeling mailbox | PASS | RUNTIME_FAIL |
| Darjeeling main | RUNTIME_TIMEOUT | RUNTIME_FAIL |
| Darjeeling peripheral | PASS | RUNTIME_FAIL |
| Earlgrey main | PASS | RUNTIME_FAIL |
| Earlgrey peripheral | PASS | RUNTIME_FAIL |
| English Breakfast main | PASS | RUNTIME_FAIL |
| English Breakfast peripheral | PASS | RUNTIME_FAIL |

The seven former passes processed zero items. The prior isolated
Darjeeling-main replay also passed with zero items. Correct callback dispatch
now exposes the missing simultaneous global-constraint mechanism; these
eight rows are not eight independent compiler defects or full-DV progress.
No unrelated classification loss was found. ADC changes from timeout to its
known runtime failure, completing in 223.518 seconds; its runtime metrics and
complete output-line multiset match the prior completed isolated replay.

Summed `semantic_debt_count` is **2223 → 2222**, entirely from diagnostic
interleaving in AES, EDN and entropy_src. Macro-warning counts, error/warning
token counts and compiler return codes are identical in all twelve compared
macro-bearing compile logs. This is not a semantic-debt reduction. Per-row evidence is in
`opentitan-root-hooks-300s-diff.json`, `opentitan-root-hooks-300s-audit.json`,
`root-hooks-macro-interleaving-proof.json`,
`xbar-root-hooks-runtime-proof.json` and `adc-root-hooks-output-proof.json`.

Caliptra remains **52 PASS / ICARUS_GAP 0**, with all 105 classifications,
inputs and tool diagnostics unchanged. The first attempt lacked the existing
harness-only `fileset_top.sv` and failed to write its report; that invalid run
is retained separately. The exact baseline wrapper was restored, and the
complete rerun ends `CALIPTRA_ROOT_HOOKS_300S_DONE=0` in
`caliptra-root-hooks-census2.log`. No external source was changed. The per-job
comparison is `caliptra-root-hooks-300s-diff.json`. This remains static
coverage, not execution of Caliptra's full UVM/DV suite.

Native design and implementation reviews are reconciled. The implementation
review found that raw runtime labels missed escaped identifiers. The shared
dynamic-method label helper now matches target encoding (IEEE 1800-2017/2023
5.6.1 and 8.20), and the new paired escaped-name regression covers pre/post
and a virtual method override through a base handle. A bounded delta review
confirmed the finding resolved, with no further findings. The requested
Claude Code CLI review is complete and reconciled. Its first run exhausted
quota, and its second retained only an acknowledgement; neither counts as a
completed review. The streaming third run returned two conditional questions.

The label question is resolved by the lexer and map insertion: labels remain
encoded, and the suffix index uses those same encoded keys. A forced exact-miss
probe selects the escaped override through suffix lookup in both editions;
changing its class suffix fails the existing assertion as a negative control.
The checker question is resolved by 18.6.2 (2017 p529 /2023 p551), which
requires pre/post on the receiver, together with 18.6.3 failure suppression
and the empty variable selection in 18.11.1 (2017 p536 /2023 p558). Neither
callback clause exempts checker calls. No code changed after the final gate
or censuses. See `root-hooks-review-reconciliation.md` and
`encoded-virtual-fallback-proof.json` in the evidence directory.

## Real DV evidence and remaining work

The unmodified Darjeeling-debug xbar smoke recompiled successfully. Its root
pre callback now creates one host sequence and four device sequences. All
five child solves succeed, but the parent dynamic-constraint pass is UNSAT.
The test reports `UVM_FATAL` at time zero despite process return code zero;
this is a failing runtime, not a PASS or evidence of exercised traffic.

`rand-member-constraint.sv` reduces that next failure to a parent foreach
constraint over a random child field. IEEE 1800-2017 18.5.9 / IEEE 1800-2023
18.5.8 require simultaneous global constraints; the existing runtime solves
children separately and the parent's `qmelem` variables are pinned to their
current values. Foreach requirements are 2017 18.5.8.1 / 2023 18.5.7.1.

`enabled-member-hooks.sv` separately demonstrates skipped callbacks on
enabled random member objects (18.6.2 in both editions). These are explicit
remaining requirements; this root dispatch increment does not close clause
18.6.2 or full DV. A HIGH-verbosity real trace also preserves a separate enum
scalar/int comparison abort. No external source was modified for any replay.

Evidence directory:
`evidence/xbar-zero-traffic-after255-arm64-20260904/` (workspace parent).
The 300-second per-process CPU limit remains in force; all six worktrees are
retained. The implementation is based on 167e8bf5d, draft PR #255, which has
not been merged by this agent.
