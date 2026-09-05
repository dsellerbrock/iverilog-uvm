# Enabled random-member callbacks — 2026-09-04

## Contract and implementation

IEEE 1800-2017 and IEEE 1800-2023 18.6.2 require automatic pre/post callbacks
on the receiver and its enabled random object members. Clause 18.6.3 suppresses
all implicit post callbacks when the outer randomization fails. Clauses 18.8
and 18.11 control enabled members and temporary explicit selection. These
rules have no implemented edition difference.

Previously only the explicit receiver got callbacks. Member solves traversed
the graph without member initialization or cleanup. The new `%randomize/pre`
operand carries an immutable root selector: `*` for the default set, empty for
checker calls, or property IDs for explicit selection. The ordinary solve
selector is still armed after all inline state capture. Scope randomization
continues to exclude object callbacks.

A per-thread stack retains each call through pre traversal, inline capture,
solve and post traversal. All pre callbacks finish before the graph solver
begins snapshots, so their procedural writes survive solver failure. Discovery
revisits current enabled edges after each callback, retains called objects to
prevent address reuse, and visits each class identity once across aliases and
cycles. It holds no container iterator while user code runs. The simple scan
costs O(V*(V+E)); its comment records that ceiling and a measured optimization
trigger. No arbitrary graph-size cap silently drops callbacks.

Pure object enumeration is shared with the existing solver at its per-property
and nested-container junctions. Fixed leaf modes, direct queue/dynamic element
modes and typed associative-key modes are preserved. Direct struct deferred
transactions, random prefills, recursive solve order and static dirty marking
remain in place. Struct values are not callback receivers, and unsupported
active struct members retain their explicit failure.

On success, post receivers are retained from the graph transaction's actual
class participants before its journal dies. A post callback can detach another
object without losing its pending callback. Failure completes and pops the
context with no post receivers. Existing automatic allocation/callf/free manage
each callback frame; old `%randomize/hook 0/1` images keep their root-only path.

## Tests and review

Five permanent tests, each registered for 2017/2023 in both harnesses:

- `sv_randomize_member_hooks`: root/member allocation, failed-solve pre side
  effects, checker selection, and root post detaching retained solved members.
- `sv_randomize_member_reachability`: late attachment below a visited ancestor,
  aliases, cycles, and a reachable member with no random fields.
- `sv_randomize_member_selection`: disabled incoming handles versus disabled
  child fields, explicit non-rand handle selection, root-only checker calls,
  inline default/explicit/checker selectors, captured state foreach and UNSAT.
- `sv_randomize_member_container_modes`: fixed arrays, D/Q and integer/string/
  object-key associative arrays; disabled elements, explicit overrides, nested
  associative/dynamic handles and associative unpacked struct values.
- `sv_randomize_member_nested_hooks`: nested explicit solves/checkers inside
  member callbacks, automatic locals, detached pending objects and a failure
  followed by success without stale callback state.

All five tests pass in both editions with trampoline and synchronous callf.
The three root dispatch tests also pass in both modes. Six old build4 callback
images run successfully on the new runtime. Native traversal and frame reviews
are complete, with no findings. Evidence: `member-hook-native-reviews.md`,
`member-hooks-focused-build3.json` (32 passes), the focused legacy/JSON logs
(16/16 each), and `member-hooks-old-bytecode-build3.json` in
`evidence/xbar-zero-traffic-after255-arm64-20260904/` (workspace parent).

The requested Claude Code CLI review is complete. Its three claims were
reconciled with source and paired-edition runtime evidence: inline selectors
already distinguish default/explicit/checker calls, nested associative object
types normalize to `Mo`, and defined callf continuations preserve call contexts.
IEEE 1800-2017/2023 9.6.2 leaves a function disabling its caller undefined.
Defined return/disable/reap/null probes pass both callf modes; depth fallbacks
were traced rather than stress-run. No compiler edit was required. See
`claude-member-hooks-reconciliation.md` and its linked proofs.

After gate3 finished, two existing tests were extended to retain the selector
and nested-associative coverage. Eight direct executions pass both editions
and callf modes, and both focused harnesses pass 16/16 again. No compiler,
registration, golden output or external input changed after gate3.

The first container setup used an existing unsupported fixed-array assignment
pattern. Its compiler warning and second-handle loss are retained separately;
the callback regression uses explicit assignments with unchanged assertions.
The first nested test's local counter assertion omitted helper checker calls
from post callbacks; its corrected assertion counts those calls explicitly.
Neither was a callback implementation defect. A direct nested checker inside
an inline constraint still gets the existing translation warning; that separate
constraint-function support gap is retained, not represented as passing here.
A captured state foreach over scalar queue elements also remains a diagnosed
IR gap; the added callback test uses the supported struct-member shape.

## Validation status

The first full gate was interrupted during legacy testing to remove a newly
introduced shadow warning. It is not a completed pass. Build2 removed the
redundant declaration; build3 only restores adjacent comment indentation.
Gate2 then found five test-adapter include-path errors (the new 2023 wrappers
omitted the harness-relative `ivltests/` prefix). Those adapters are fixed;
both focused harnesses pass 16/16, including all wrappers. VPI 103/103 and
negative 149/0 passed in that interrupted run, but it is not a full gate pass.
Gate3 now passes legacy 4567/4572 with zero failures (2 NI, 3 EF), clean name
diff, JSON1461/0, VPI103/103, negative149/0, runtime invariants, and
real-DPI UVM355/0/0. `MEMBER_HOOKS_GATE_DONE=0` closes the full gate.
The sequential application censuses have completed on unchanged build3. Native
ARM64, Homebrew Bison 3.8.2, serial make followed by make install, and the
user-authorized 300-second per-process CPU guard remain required.

Comparison baseline: root commit c5d07f600, draft PR #256 stacked on #255.
All 530 OpenTitan classifications and inputs are unchanged: **203 PASS**.
Summed `semantic_debt_count` changes **2222 -> 2223** solely from compile
output interleaving (runtime EDN +1, runtime entropy_src -1, UVM entropy_src
+1). Raw warning/error token totals and return codes match; no semantic
warning was added or removed. All 26 runtime output line multisets match
apart from the harness duration header. ADC completes in 187.935s against
223.518s before; the existing TL agent timeout remains. All eight xbar
runtime rows still fail at time-zero randomization with zero scoreboard items.

All 105 Caliptra classifications, inputs and tool diagnostics are unchanged:
**52 PASS / ICARUS_GAP 0**. Exact per-row diffs and raw-log reconciliation are
`opentitan-member-hooks-300s-diff.json`, `opentitan-member-hooks-300s-audit.json`,
`caliptra-member-hooks-300s-diff.json`, `member-hooks-runtime-payload-diff.json`
and `member-hooks-census-reconciliation.md` in the evidence directory.
`MEMBER_HOOKS_300S_CENSUS_DONE=1` denotes existing failed OpenTitan rows;
`CALIPTRA_MEMBER_HOOKS_300S_DONE=0` and the coordinator's completion marker
close the sequential run. No external source was changed. Installed hashes
remain those recorded in `member-hooks-build3-binaries.json`.

## Remaining requirements

Simultaneous global constraints remain unimplemented (IEEE 1800-2017 18.5.9 /
IEEE 1800-2023 18.5.8). Children still solve independently before the parent,
which pins cross-object variables. Callback execution does not repair this
solver architecture or establish full OpenTitan/Caliptra DV. Constraint
function captures, unsupported struct member shapes, fixed class-array
assignment patterns, class-metadata quoting and the HIGH-verbosity enum abort
remain separate evidence. Full clause-18 and full IEEE/DV completion are not
claimed by this increment.
