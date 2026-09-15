# Function-valued constraint implementation (in progress)

Base: local `cc66db23e`, after L63 method dispatch integration. Worker reused on
`agent/constraint-function-presolve-20260914`; no new worktree or agent.

## Required semantics

IEEE 1800-2023 18.5.11 / 2017 18.5.12 require function evaluation before solving,
with return values treated as state. Random function arguments establish priority
partitions; old random values cannot be substituted. Circular dependencies error.
Functions cannot have output/inout/ref formals (const ref allowed), retain mutable
state, modify constraints, or have side effects. Active-call count/order is not
fixed, so tests do not assert exactly one call. Constraint modes, inheritance,
and virtual dispatch remain part of the implementation requirements.

The initial implementation path uses typed value slots and per-constraint call
metadata transported through existing class metadata. The existing randomize
continuation invokes state functions after pre_randomize and before solving,
using ordinary method frames, implicit-this, virtual lookup, and function return
vectors. Disabled blocks must skip both evaluation and assertions. Overridden
blocks must replace their inherited call metadata. Zero-argument integral calls
are the first implementation slice, not completion of general function support.

## Independent evidence

All evidence below is under `evidence/uvm-release-regression-assessment/semantic/`.

- Existing state-change, mode/unsatisfiability, virtual-override and exact UVM
  pick_sequence reducers establish the ignored-constraint failures. Direct
  controls validate the underlying state/mode and virtual-call behavior.
- `argument-baseline.json`: state-input and random-input function constraints
  produce wrong values in both editions; isolated output/inout/ref function
  fixtures incorrectly compile and run. The random-input test forces y=9 and
  requires x=f(y)=10, making an old-y pre-evaluation observably wrong.
- `typed-state-baseline.json` and `typed-state-2state-baseline.json` retain the
  initial combined width/sign probes. Their direct controls also fail, so those
  results alone do not isolate function evaluation.
- `typed-direct-isolation.json` isolates the cause: signed 32-bit direct state
  equality passes both editions, whereas a 128-bit direct state read returns
  randomize failure with an explicit unsupported-width diagnostic. The latter
  is an existing transport limitation, not evidence of a new function bug.

Status: implementation underway. No claim of support, integration, or corrected
broad qualification yet. Keep unsupported cases explicit until implemented.

## Inheritance and nested-object review

`inheritance-baseline.json` adds two paired cases: distinct base/derived function
slots and same-name constraint override with mode disable/re-enable. The four
direct-state controls pass; the function forms fail or lack mode lookup.
The existing merge prepends inherited blocks, so descriptors must travel with
constraint entries or have every slot reference rebased consistently.

`nested-pre-state-baseline.json` confirms direct-state child constraints observe
parent pre_randomize updates (both editions pass). Two child objects using the
same function declaration return wrong randomized values with ignored function
constraints. The new evaluator must key captures by runtime object as well as
constraint/slot identity and run after pre callbacks.

Review of existing substitute_slots found a missing-slot fallback to zero and
widths above 64 coerced to 32. These are not acceptable defaults for new function
results: validate complete typed captures before substitution, or repair the
shared helper. Worker notified; no unsupported path may silently become zero.

## Metadata review checkpoint

The first metadata edits were reviewed before build. Method name alone cannot
preserve nonvirtual lexical binding versus virtual dispatch; descriptors need
resolved method identity/qualification. `nonvirtual-hiding-baseline.json` records
passing ordinary-call/direct-constraint controls in both editions, while the
function constraint is currently ignored. IEEE 1800-2023 8.20 governs this
binding distinction.

An in-progress flattened-slot rebase would leave multiple root blocks sharing
indices and rebase already-rebased inherited IR in deeper hierarchies. Worker
was asked to preserve entry-local immutable IR or use entry-local substitution.
Raw token replacement must also respect boundaries such as existing qv tokens.
`three-level-slots.sv` and `multiple-block-slots.sv` were prepared for the new
implementation. These are review findings on unfinished code, not claims about
an installed regression.

## Focused runner

`semantic/run-focused.py` provides a repeatable paired-edition check with source
and installed-artifact hashes, compilation/runtime logs, positive pass markers,
and isolated negative cases. `complete-baseline.json` records 0/32 passing on
stable preimplementation artifacts. It intentionally includes the full desired
argument/width scope, so partial support cannot be reported as full completion.

The runner now also includes `uvm-sequence-reader.sv` (34 total cases). The
additional two baseline results are in `uvm-sequence-reader-baseline.json`:
compilation succeeds with ignored constraints and runtime fails. This reducer
mirrors the actual UVM1.2 read chain: null receiver guard, nested method call,
then string-queue size. The queue changes between randomizations. An early
fixture used the reserved word library as an identifier; that fixture was
corrected before recording the current semantic baseline.

## Executable spike review

The first installed codegen-only candidate passes 20/34 focused cases on stable
hashes (`first-codegen-review.json`); the worker independently reproduced20/34.
This proves ordinary function execution and several state/mode/inheritance
values, but is not an integration candidate. Per-call-site static metadata
cannot supply all dynamic objects or honor disabled-call evaluation rules.

Three additional paired runtime failures concretely establish the carrier gaps:
`receiver-once-intermediate.json` evaluates an indexed receiver twice while its
direct control passes; `dynamic-derived-intermediate.json` produces x=11/y=0
instead of x=11/y=29 through a base handle; `inline-state-intermediate.json`
produces x=29/y=29 instead of x=3/y=29, aliasing inline and class call slots.
Compiler observed: f4439c2265e917d44d41909fd3733d78feb90c8bca140d85ab4744d3e2ca0cdd;
target: 0e7fffbceff4eb07735b2cfb037cd71ff8ee808cd32d3726ab749118afb77bf8.
The focused runner now includes these three shapes (40 edition cases).

Worker agreed to replace the static carrier with runtime per-object descriptors.
No spike changes are committed or qualified. Existing known argument/width and
illegal-formal failures remain part of the required scope.

Runtime migration review identified an existing transport path: vvp_z3_object_s
already represents each selected runtime object and carries full-vector
slot_words. The graph collector currently copies inline values only to the root
record. Class-function captures should travel separately per object through this
existing graph, preserving inline namespaces and receiver ownership in the
randomize call context. This avoids duplicating the object-graph model.

Argument-conversion controls (`argument-conversion-intermediate.json`) establish
that ordinary signed-byte narrowing and const-ref calls work in both editions;
the corresponding constraint calls still fail in the installed spike. Runtime
formal binding must preserve those conversions and permit const ref as required
by 18.5.11. These additional cases are separate from the40-case runner.

Descriptor transport is now being implemented through ivl_target.h and VVP
class metadata. Review caught an internal NetScope pointer returned as the
distinct target ivl_scope_t type; worker was directed to the existing dll_target
scope bridge instead of pointer substitution. No runtime migration build is
qualified at this checkpoint.

The runtime migration has removed the static call-site carrier from source.
Descriptor transport now uses a stable method scope name instead of an invalid
NetScope-to-ivl_scope_t conversion, and VVP .constraint_call parsing is present.
Execution and solver integration remain under construction.

The focused runner now returns nonzero on any failing case or artifact-hash
change, and illegal-formal cases require the intended function-in-constraint
diagnostic. `runner-exit-check.json` verifies20/40 with stable old-spike artifacts
and process exit1. This runner check is not a new runtime build result.

Solver review: dedicated class_slot_vals has been added to per-object solver
records. A draft compatibility fallback reused inline slot_vals when the new
class pointer was absent; worker was asked to remove that alias and diagnose
missing active captures explicitly. The earlier inline-state test is the
regression oracle for this exact failure. Per-call evaluation context fields
are present; function-frame execution is still being completed.

Evaluator source review found that clearing pre_called before state-function
execution would cause pre_randomize callbacks to run again on each instruction
re-entry. Worker was asked to separate the completed-callback phase from state
call continuations. `pre-once.sv` checks two functions across two randomizations,
counting only pre_randomize callbacks (whose lifecycle is defined), not the
unspecified number of constraint-function calls. Runner now42 edition cases.

Further review: selected-object traversal must honor the root selection;
virtual target resolution must fall back through runtime_super; lookup/frame
failure must finish with an explicit error rather than silently halt; X/invalid
results must prevent the solve. These are pending checks on unbuilt code.

## First runtime migration build

Worker build/install completed (session72086 exit0). Root inspected
`semantic/runtime-migration-first.json`: stable artifacts and36/42 passing.
Receiver-once, dynamic-derived, inline slots, nested objects, pre-once,
virtual/nonvirtual dispatch, modes, inherited blocks, and illegal formals now
pass the focused matrix. This supersedes the static-carrier spike as the current
implementation checkpoint, but is not integration qualification.

Remaining paired failures: state arguments read an unbound formal (x=1), random
arguments still take an ignored-constraint warning path, and128-bit function
returns remain ignored. Signed32-bit return in the typed probe is now correct.
Worker continues argument binding/conversion, typed transport, and ordering;
ignored paths must be removed before any support claim.

Installed compiler SHA256:8bd0cdfa2eed9cd2297a98db961fda0e4cc14c09e8bdd05e3b79a4a1a4b331d8;
target:2a9cc1fd300afb7de2cdc364d6ec8b720d6f0fe885f8488db0b32c95e7775d3c;
runtime:5c09ca9612ec64700de7ed618757db3b1b91cbf9e49026fb81b9e59716aebb08.

## Random-argument ordering review

Existing Z3Builder::OrderRef/order_pairs and the `(order ...)` IR implement
solve-before distribution ordering with a shared global feasibility problem.
The source explicitly identifies this as sampling partitioning, not separate
solving. IEEE 1800-2023 18.5.11 function-argument priorities differ: higher
priority constraints solve without lower-priority feasibility, and can cause
subsequent failure. Reuse dependency/ref/topological helpers, but ordinary
solve-before encoding cannot implement this semantic requirement. Worker
notified before beginning the argument-order stage.

## Typed argument ABI checkpoint

The compiler now records each state-property argument's formal name, width,
two-state type, and source signedness. VVP emits and parses this metadata and
initializes input formals in the automatic function frame with assignment
conversion. The first build exposed an invalid NetNet basename accessor,
corrected to name(). Build and install then completed successfully.

`semantic/argument-abi-first.json` records 38/42 passes with stable installed
artifacts. The expanded `semantic/argument-abi-extended.json` records 40/48:
state arguments and signed narrowing conversion pass in both editions.
Remaining failures are random-argument priority solving, 128-bit returns,
const-reference acceptance, and inherited virtual dispatch. These failures
remain explicit in the runner; this checkpoint is not integration qualification.

Runtime review shows const-reference formals need existing bind_prop storage
binding rather than a value write. Inherited virtual calls also need the same
runtime_super lookup walk already used by randomize callbacks. Repairs are
in progress, including failure-path PRE context completion.

Wide-return follow-up must cover both capture transport and constant parsing:
class_slot_vals/state_values currently use uint64_t, substitute_slots narrows
widths above 64, and c: atoms use strtoull plus Z3_mk_unsigned_int64. Merely
removing the elaborator width guard would truncate values. Missing slot
indices also currently substitute zero and unknown atoms default to true;
active class captures must be validated before invoking those legacy paths.
These are open correctness issues, not accepted implementation limits.

## Inherited virtual dispatch repair checkpoint

Rebuild/install completed successfully after the runtime superclass walk and
reference-binding changes. `semantic/argument-ref-fixed.json` records 42/48
passes with stable artifacts: inherited virtual calls now pass in both modes.
Const-reference acceptance remains incorrectly rejected at compilation; the
new metadata lookup did not resolve it. Both type-mismatch negative probes
also report the wrong non-const diagnostic, as recorded in
`semantic/const-ref-type-mismatch-results.json`. The compile-time const
qualifier mapping is being investigated further; runtime reference binding
is not yet validated by a passing end-to-end test.

No broad suite or local integration was performed at this checkpoint.

## Const qualifier root cause and wide transport work

The parser's tf_port_direction_opt discards const on reference formals before
elaboration; matching parse-form ports by name therefore cannot fix acceptance
on its own. A frontend worker is repairing actual qualifier propagation.
Runtime capture now retains vvp_vector4_t results, and the direct/graph class
slot transport is being converted to full vectors separately from inline slots.
The solver worker is implementing width-preserving substitution with explicit
missing/unknown capture checks.

Added signed-128 return, wide-input argument, and unknown-return rollback/retry
probes. `semantic/wide-transport-baseline.json` records 42/52 passes on the
previous installed artifacts before these transport changes; the runner now
includes the additional rollback probe for a total of 54 cases. No build of
the new vector transport has yet been qualified. Worktree audit still shows
only the retained controlling and active campaign trees; no clones were made.

## Full-width and const-reference focused checkpoint

Frontend const qualifier propagation, full-vector capture transport, and
arbitrary-width scalar model writeback built and installed successfully.
`semantic/fullwidth-first.json` recorded 50/54 passes. The signed-wide probe
exposed a pre-existing mixed Bool/bitvector equality error; the shared binary
comparison path now converts relational Bool operands through bool_to_bv1
before width/sign handling. A direct relational-result regression reproduced
the same error independently of function captures.

After that repair and explicit writeback width-failure propagation,
`semantic/fullwidth-comparison-fixed.json` records 54/56 passes with stable
installed artifacts. Only random-argument priority ordering fails in this
focused matrix (both editions). Const-reference, 128-bit values/arguments,
signed-wide comparison, and unknown-return rollback/retry pass.
`semantic/fullwidth-neighbors.json` records correct const-reference type
mismatch diagnostics and ordinary reference regression passes, both editions.
`semantic/const-ref-write-results.json` records rejection of writes through a
const ref. `semantic/const-ref-continuation-results.json` records comma
continuation and explicit bare-ref qualifier reset passes, both editions.

These are focused implementation results, not full conformance or integration
qualification. Purity validation and unsupported call-expression shapes still
need review in addition to staged random-argument solving.

Priority work must retain one rollback-capable transaction across stages and
run function calls only once their random arguments have been solved. Inline
constraints are captured after PRE, so resumable solve opcodes must own the
plan. Partitioning entire named constraint blocks is insufficient: a block
may contain both y==9 and x==f(y), which must participate in different stages.
Item-level dependency handling must preserve conditional/foreach semantics.

## Priority solving checkpoint

Function arguments now carry runtime selection semantics through a staged
solver plan. Top-level constraint items are separated while nested control
scopes remain intact. The runtime retains one graph journal and inline capture
set across function-frame suspensions, freezes completed argument stages,
and commits only after every stage succeeds. Missing/unsupported planner
references diagnose instead of dropping an item.

`semantic/priority-first.json` records 72/72 passing cases on stable installed
artifacts, including chained dependencies, inline argument restrictions,
explicit non-rand selection, mode-disabled state arguments, late-failure
rollback/retry, multi-variable cycle errors, and frozen self/argument-only
checks. Twelve representative source tests were promoted into permanent
legacy/JSON regressions with both edition entries. The two focused harnesses
pass 24/24 each (`semantic/priority-permanent-legacy.log` and
`semantic/priority-permanent-json.log`).

The unchanged pinned UVM 1.2 smoke passes compile/runtime in -g2012:
`third_party/uvm-releases/results-msjdvv2u/results.json`; only the DPI export
stub note appears at compilation, and runtime reports zero UVM warnings,
errors, and fatals. A separate concrete derived-sequence probe exercises the
actual unmodified library pick_sequence constraint against a null sequencer,
three/five queue entries, changed size, inline restrictions, mode toggles,
and failed-solve rollback. It passes UVM_PICK_SEQUENCE_PASSED with compile/
runtime zero in `semantic/uvm12-pick-sequence-results.json`. The first probe
incorrectly instantiated the abstract library base; the corrected harness
uses a concrete subclass without modifying UVM sources. This is focused
mechanism evidence, not full UVM qualification.

Purity remains in progress. Four illegal function-body probes (external
write, transitive write, RNG, and mode mutation) compile before the validator
in both editions (`semantic/purity-before.json`). The first validator build
failed on a nonexistent lifetime enum. Review also found missing traversal
failure propagation and an overly permissive system-function classification;
these are being repaired before any purity or completion claim.

Parser generation recorded 562 shift/reduce and 1122 reduce/reduce conflicts
for the frontend in fullwidth-build.log, and 14/5 respectively for the VVP
parser in priority-build.log. These counts are recorded, not claimed improved.
No broad suite, merge, or remote publication occurred at this checkpoint.

## Purity and remaining-variable priority repair

The first built purity visitor rejected legal return lowering;
`semantic/purity-first.json` records that regression (2/72), and
`semantic/purity-specific-first.json` records the direct-loop rejection.
The validator now accepts disables local to the automatic function, including
generated returns, while rejecting external disables. Formal legality checks
precede purity checks. `semantic/purity-return-fixed.json` restores 72/72;
the eight illegal-body edition probes reject and the pure transitive local
loop passes in `semantic/purity-specific-return-fixed.json`.

A new ordinary-peer test exposed an additional priority error: with y==9,
x==f(y), x==z, sampling z in the first stage freezes a lower-priority variable
and can fail a satisfiable solve. The planner now places active function
arguments in their dependency tiers and all remaining random variables in
the final lower tier. Inputs of the same function do not impose artificial
ordering on one another. `semantic/priority-peers-fixed.json` records 86/86
passes with stable binaries, including the peer and multiple-input tests.
The original UVM 1.2 pick_sequence probe still passes with purity enabled
(`semantic/uvm12-pick-sequence-purity-results.json`).

Arbitrary actual-argument expression lowering and non-property staged
references still have explicit unsupported paths. No full function-support
or broad qualification claim is made. The source remains uncommitted pending
review and remaining coverage work; no worktree was created or retired.

## Ordinary-call wrapper checkpoint (pending validation)

The preceding `staged-state-fixed.json` checkpoint passed 90/92 focused cases
with stable installed artifacts. State container size now works; the two
remaining failures are queue-element state reads in 2017 and 2023. A direct
constraint control also fails: the frontend omitted `q[0] == 7`, allowing a
second solve after q[0] changed to 8. This is not an unsatisfiable-solver issue.
The pending frontend correction emits the existing `delem` representation.

The implementation now uses a compiler-generated automatic wrapper containing
ordinary call elaboration, replacing bespoke argument transport/binding. This
reuses normal conversion, named/default arguments, const-ref selection, and
virtual call machinery. Metadata records argument property dependencies; the
wrapper receives the runtime object and returns the full typed value.

Review identified direct static-property signals missing from dependency
collection and a fail-open traversal for unclassified expression nodes. Those
are being repaired before integration. Active element/member/size dependencies
also need typed identities and stage selection: a root property ID alone cannot
represent their independent ordering. They remain an explicit implementation
gap, not a supported subset. No broad qualification or local merge is claimed.

## Wrapper first-build results

`wrapper-build.log` / `wrapper-install.log` completed successfully with serial
make. `wrapper-first.json` records 106/108 passing cases with stable artifact
hashes. New argument expressions, named/default arguments, nested calls,
const-ref selected arguments and the extended purity negatives pass both modes.
The two queue-state failures now compile with no diagnostics, but runtime emits
an out-of-bounds dynamic-element warning and drops the assertion. The existing
queue size must be used for inactive containers; this remains under repair.

`uvm12-pick-sequence-wrapper-results.json` records compile/runtime exit zero and
`UVM_PICK_SEQUENCE_PASSED` for the unmodified UVM 1.2 constraint probe.
`static-dependency-before.json` confirms a separate wrapper dependency omission:
2017 and 2023 both solve static y to 9 but evaluate identity(y) using old y=2.
The static signal identity fix is present in source but not yet built here.

## State bounds and static transaction checkpoint

`wrapper-state-fixed.json` records 108/110 with stable installed artifacts.
Queue element constraints now pass their initial valid-last-element solve and
reject changed state with rollback in both modes. Static dependencies are now
present in emitted metadata, but the static argument reducer still reads 2
while the solver stages 9. `class_type` transaction cells intentionally defer
backing signal updates until commit; ordinary function reads bypass those cells.
The next correction must expose staged reads without committing or delivering
signal-change events early. `static-rollback-before.json` additionally proves
late-unsat rollback already restores old values, then the following successful
solve incorrectly computes x=3 rather than 10 from staged y=9.

Permanent focused manifests now contain 50 edition-specific cases, including
12 newly promoted shapes and a static late-unsat/retry check. They await execution
against the static-read correction; no passing count is inferred from registration.

## Scoped static reads validated

The static signal registry now exposes transaction values only to an executing
staged constraint-function call and its synchronous callf descendants. Const-ref
proxies resolve their current binding before lookup. Normal static-formal overlays
keep precedence. Backing signals are published only at commit; class teardown
removes registry entries. Review rejected an earlier globally visible read bridge
before building it.

`static-overlay-build.log` and `static-overlay-install.log` completed successfully.
`static-overlay-fixed.json`: 118/118 positive/negative cases, paired editions,
stable installed artifacts. This includes direct/static const-ref arguments,
nested helper static reads, late-unsat rollback/retry, and event checks proving
zero static-change events on failure and one on successful commit.
`uvm12-pick-sequence-static-overlay-results.json`: compile/runtime exit zero,
`UVM_PICK_SEQUENCE_PASSED`, original UVM 1.2 probe.

The first permanent run caught missing split-stream gold files for 12 promoted
shapes, plus default `$finish` chatter in the event test. Added the missing exact
PASSED/empty stream gold files and used `$finish(0)` without changing assertions.
`static-overlay-permanent-fixed.json` and its logs: legacy56/56 and JSON56/56,
stable binaries, no skips/expected failures. `git diff --check` passes.

Residual work: typed MEMBER/ELEM/SIZE dependency identities and stage selection;
static fixed-array word bindings need a leaf-aware overlay. Packed selected
static const-ref semantics pass separately (`static-selected-after.json`) but
normal call lowering emits an unsupported copy-out warning even for const-ref;
that diagnostic/copy-out path remains to review. Purity negatives still need
permanent registration. Broad qualification and local integration remain pending.
Worktree audit still finds only the retained dirty controlling checkout and this
active campaign checkout; neither is eligible for retirement.

## Typed dependencies and permanent purity checks (next increment)

The prior goal turn made implementation progress: scalar static transactions and
118 focused checks were validated. This increment promotes all 10 negative shapes
(output/inout/nonconst-ref plus seven impurity cases) with paired sources,
compile-error JSON, exact stderr/stdout gold, and both main/focused registrations.
The Perl harness prefixes source paths with `./`; its separate legacy gold now
matches that convention. `purity-registered-fixed.json`: legacy76/76 and JSON76/76
against the frozen scalar-static checkpoint. All referenced source/config/gold
files exist and every name occurs once in each of four manifests.

Selected packed const-ref actuals previously emitted an unsupported copy-out
warning despite passing runtime assertions. The pending ordinary-call fix keeps
copy-in/aliasing and skips copy-out for const-ref formals, including the companion
fallback. Nonconst ref retains its existing writeback behavior.

Typed argument metadata now carries PROP/MEMBER/ELEM/SIZE, property, and leaf.
`typed-dependencies-before.json` records failing paired function forms;
`typed-direct-controls.json` confirms fixed/static-array and queue-size direct
controls pass. The first member fixture incorrectly used nonrandom record fields;
it was corrected to explicit rand members before the typed build. The direct
queue-element growth control additionally exposes that delem cannot bound an
active future element using its old size. This remains open with dynamic staging.
`typed-modes-before.json` pins a failing inactive-element case and passing
neighboring randc cycles. No typed implementation success is claimed before build.

## Typed first-build findings

`typed-first.json`: 128/138, stable artifacts. New instance/static fixed-array
input calls, instance selected const-ref, element rand_mode state, and neighboring
randc cycles pass. Failures are paired selected const-ref warning, static-array
const-ref late-unsat leak, member priority mismatch, and two dynamic-container
shapes. The first selected const-ref change in PCallTask was insufficient:
function-expression copy-out in `tgt-vvp/draw_ufunc.c` independently performs
writeback. The pending fix adds target const metadata and skips that copy-out,
including virtual-interface function paths, without changing writable ref behavior.

Member metadata is correct but solver graph IR uses synthetic child PROP storage
while the planner retained outer MEMBER identity. That duplicate allowed a later
stage to randomize an already solved member. The pending canonicalization maps
both to one ordering identity while selecting the matching storage in its stage.
`member-direct-corrected.json` confirms direct rand-member constraints pass both
editions, isolating the staged failure. The broad gate remains pending.

## Fixed-element/member checkpoint validated

`typed-member-ref-build.log` / install log completed successfully.
`typed-member-ref-fixed.json`: 134/138 with stable artifacts. Only the paired
`typed-size-priority` and `typed-queue-element` dynamic cases still fail; they
remain positive expectations, not skipped tests or claimed support. Selected
const-ref diagnostics are clean, static fixed-array const-ref rollback now
restores both leaves, and member ordering yields b=9, x=a=10.

`typed-member-ref-permanent.json`: legacy92/92 and JSON92/92, no skips/expected
failures. `typed-copyout-neighbors.json`: six existing function return/ref and
scalar output/default tests pass in each harness. The runtime copy-out context
malformed-bytecode checks pass6/6. `uvm12-pick-sequence-typed-results.json` compiles
and runs with exit zero and UVM_PICK_SEQUENCE_PASSED against unchanged UVM 1.2.
`git diff --check` passes. No merge, publication, or new worktree was performed.

Next dynamic implementation should reuse the existing DynForeach two-pass path:
create typed SIZE nodes, add inherent SIZE-before-ELEM edges, retain exact
argument-leaf tiers, and materialize the remaining active leaves after size is
solved rather than enumerating only the old container. Size pinning, sampling,
and writeback must use rand_size_active_. A prospective active delem must defer
bounds checking until solved size is available; inactive/state bounds remain
immediate. This is required for q growing from one to two elements before q[1]
is solved and f(q[1]) is evaluated. It is still unimplemented, not qualified.

## Dynamic staging implementation started

The preceding goal turn made concrete progress: typed fixed-element/member
ordering and const-ref copy-out were corrected and validated. This increment
uses those installed artifacts as the baseline and extends the existing size and
element solver passes. `dynamic-extended-before.json` records paired failures
for growth/shrink/retry rollback and mode re-enable. A cycle reducer requires an
explicit circular-priority diagnostic and original values preserved. A dynamic
randc-neighbor reducer checks per-leaf cycles across size/element stages.

ABI review (`abi-dynamic-before.json`) confirms exact nonstatic ELEM/SIZE
metadata, including a passing inactive dynamic-element state case. Static dynamic
indexed arguments were incorrectly sent through the static-record classifier;
indexed array classification now precedes that branch. Runtime static containers
also use direct qsize/dynamic-load opcodes, requiring the same scoped transaction
visibility as ordinary loads. These changes await coordinated build/validation.

The focused runner now also rejects runtime messages claiming ignored or
unenforced constraints; numeric assertions alone cannot excuse such fallbacks.

## Dynamic first-build results

`dynamic-stages-build.log` / install log completed successfully.
`dynamic-first.json`: 154/164 with stable artifacts. Size-before-element ordering,
direct prospective element growth, empty/default-empty queues, size modes,
ordinary lower-tier peers, static size reads, and the dynamic cycle diagnostic
pass. `dynamic-direct-controls-fixed.json` confirms the direct queue growth
control now passes in both editions, repairing its earlier old-bound rejection.

Remaining failures: two foreach-related shapes in both editions, both static
dynamic element call shapes at compile time, and the dynamic randc neighbor cycle.
The first static frontend reorder did not cover the actual netlist form:
`-N` shows NetESelect(NetESignal(static container), constant index). The collector
now recognizes that exact form rather than rejecting its whole aggregate base;
this follow-up is not built at this checkpoint. The randc case repeats a value
on iteration3 and remains under investigation rather than waived.

Nine newly passing shapes have permanent paired regressions and exact stream
golds, increasing the registered focused manifest to110. Their harness execution
is still pending the next coordinated build. Foreach containing an argument
ELEM currently receives a broad explicit unsupported diagnostic; per-iteration
post-size repartition remains required, including bodies that exclude that index.

## Dynamic leaf checkpoint validated

The preceding status-only answer added no implementation evidence; this goal
continuation resumed the pending coordinated build. `dynamic-leaf-fixed-build.log`
and install log completed successfully. `dynamic-leaf-fixed.json` records160/164
with stable hashes of all four installed artifacts. Static dynamic element input
and const-ref calls now pass both editions. Materialized active dynamic ELEM leaves
receive solver variables even when absent from constraint IR, so the final element
stage samples and records randc history exactly once. The queue cycle test also
checks failed-call value rollback and preservation of remaining cycle choices.
SIZE-stage placeholder values are not recorded as final history choices.

`dynamic-leaf-permanent.json`: legacy110/110 and JSON110/110. Three newly validated
shapes were then promoted with paired edition regressions and stream golds;
`dynamic-leaf-promoted.json`: legacy116/116 and JSON116/116, no failures, no skips,
no expected failures, stable artifacts. `uvm12-pick-sequence-dynamic-leaf-results.json`
records successful compile/runtime and UVM_PICK_SEQUENCE_PASSED with unchanged
UVM1.2 sources. Broad qualification is still pending; no commit or merge was made.

The runtime agent corrected its earlier claim of a separate ordinary dynamic-randc
bug: the attempted replacement had not changed the function call, so the supposed
control reran the staged case. A verified no-function control passes; persistent
paired control evidence is being recorded. Do not treat the invalid control as a
separate compiler defect.

Remaining focused failures are dynamic-foreach-argument and
 dynamic-element-repeat-rollback in both2017 and2023. Both use f(q[1]) outside
foreach. Their next implementation requires post-size body expansion and exact-leaf
repartition; it does not require per-iteration function captures. In-body function
calls remain a separate coverage extension. Two existing cheaper agents are reused
for runtime implementation and frontend/ordering review; no new worktrees exist.

A new cheap neighbor reducer, `dynamic-unrelated-foreach.sv`, confirms that the
same guard rejects foreach on a different container from the function argument.
`dynamic-unrelated-foreach-before.json` records compile0/runtime1 in both editions.
The focused runner now has166 cases; the last complete160/164 checkpoint predates
these two added positive expectations. The runtime agent is implementing the
remaining foreach stage-tail expansion; no subsequent build is claimed yet.

## Foreach review and static-member follow-up

Prepared the existing seven batch gates under
`evidence/batch-20260914-l64/qualification/`, adding six installed-resource hashes
before/after each gate. They have not run. Integrated/JSON harnesses remain serial;
frontend relocation must run last and alone.

The first guarded foreach partition was reviewed before building. It replaced
argument-iteration dependency sets with only the argument leaf, which would
incorrectly move mixed constraints such as q[1]==x to the argument stage. The
local IEEE1800-2023 §18.5.11 text requires early constraints to contain only the
higher-priority variables; §18.5.12 also makes loop-index predicates guards.
Runtime correction is in progress: collect actual substituted-body references,
retain later dependencies, and eliminate false loop-guard branches.

Independent frontend review found static unpacked-record f(s.b) emitted PROP(s)
instead of MEMBER(s,b). The nested member/select representation had lost the
exact dependency. A focused reducer is preserved as abi-review-static-member.sv;
paired captured baseline and a frontend repair are in progress. These findings
are remaining compiler work, not waived tests or completed qualification.

## Foreach/member first combined build

`foreach-member-build.log` and install log completed0. `foreach-member-first.json`
records170/176 with stable installed artifacts. The previous foreach failures,
unrelated-container foreach, mixed lower-ref iteration, and future-body leaf
all pass both editions. Root added a two-argument foreach reducer to exercise
multiple exact partitions and rollback; it compiles but randomize returns0.

The static-record input and const-ref shapes still fail, and freshly emitted
VVP still carries PROP rather than MEMBER metadata. The first carrier-recognition
patch did not match the actual representation; it is not claimed fixed.
The frontend worker is tracing the actual form, while the runtime worker handles
the multiargument foreach failure. Both use cheap focused evidence; no new agents,
clones, or builds beyond the coordinated candidate build.

`foreach-member-permanent.json` passes116/116 in each harness with stable artifacts.
Five validated foreach shapes were promoted (ten edition cases), bringing the
registered manifests to126; `foreach-promoted` replay is pending at this entry.
The seven full gates remain prepared, not executed, pending these focused fixes.

`foreach-promoted.json` completed: legacy126/126 and JSON126/126, stable hashes,
zero failures/skips/expected failures. `git diff --check` passes.

## Static member and multiargument foreach corrections

The static member representation was traced to its actual class: printed
`s[-2:0]` dimensions come from NetESignal::dump, not a NetESelect carrier. The
frontend now recognizes NetEProperty(base=NetESignal(static record)) directly and
emits MEMBER. The speculative carrier-peeling branch was removed. Indexed record
members remain explicitly unsupported rather than mislabeled as outer ELEM.

The multiargument foreach failure came from syntactic references in constant-false
branches. Exact iteration bodies now use the real IR AST, resolve signed-constant
aliases and simplify constant guards, then retain only typed variables present in
the resulting AST. This lets q0/q2 constraints solve before f(q0,q2), while q1/x
remain lower peers. Prospective dynamic element references are recorded in this
real parse path, retaining future-leaf staging.

`foreach-static-final-build.log` and install log completed0. The frozen
`foreach-static-fixed` focused176 replay is running; no result claimed yet.

## Focused checkpoint green; broad batch started

`foreach-static-fixed.json`:176/176 with stable installed hashes. Both static
record input/ref success and rollback now pass, as does multiargument foreach
with late-UNSAT rollback. The three shapes were promoted, bringing registered
focused manifests to132 edition cases. The last exact focused-harness replay
was126/126; the six new entries will be exercised by the broad harnesses.

`evidence/batch-20260914-l64/qualification/candidate.json` freezes source files,
test inputs and installed hashes. Integrated, UVM, releases, and NFA gates started
against that frozen candidate. Exact live session handles are recorded beside it.
Both workers are holding source edits. JSON must follow integrated due shared
harness logs; frontend runs last alone. Qualification is pending, not passed.

First broad results: releases gate exit0, all15 SMOKE_PASS, complete and baseline_valid;
NFA gate exit0,58/58. Six installed-resource hashes are stable for each gate.
The exact release results were copied to qualification/release-results.json with
original results-hxw2c4ul path retained. This is unmodified compile/factory/copy/
phase/regex/HDL smoke evidence, not full release-specific UVM/DPI ABI qualification.
Integrated and UVM gates remain live; JSON, makecheck and frontend are pending.

Fresh targeted UVM1.2 replay also passes against this frozen candidate:
`uvm12-pick-sequence-foreach-static-results.json` records compile/runtime0,
UVM_PICK_SEQUENCE_PASSED, and stable four-artifact hashes. Both live broad sessions
were polled again: integrated96066 and UVM64665 remain running, not terminal.
ABI agent is reviewing runtime partition code read-only; all source edits remain
on hold until the batch finishes. No commit/merge or full qualification claim.

## Broad integrated gate found four regressions

Integrated gate completed exit1: legacy5179total,5170pass,4fail,2NI,3EF.
Failures: sv_constraint_foreach_assoc_state and its2023 variant,
sv_randc_constraint_provenance, sv_randc_container_transactions. VPI108,
negative149, runtime15, copyout6 and exports66 pass. Installed hashes stayed stable.
The JSON sweep started next (session63603); UVM64665 remains live.

Current authoritative per-test legacy evidence is `<test>.log` in
qualification/legacy-test-logs. The copied folder also contains old JSON stream
logs; do not use those stale *-stdout/stderr files to interpret this legacy run.
The associative foreach and randc container logs report ignored constraint items
followed by semantic assertion failures. The provenance test reports explicit
unsupported function-call diagnostics. No oracle or expectation was weakened.
Both workers are diagnosing read-only while the remaining frozen gates finish.

JSON gate completed exit4:2115 tests, same four failures as legacy. makecheck
completed exit0; installed hashes remained stable. UVM64665 remains live,
frontend pending until it finishes.

Read-only diagnosis confirms an accidental early indexed_assoc return in
constraint_state_prop_ok_ rejects valid integral associative foreach before
runtime template lowering. Removing that early return will restore the existing
supported path while retaining the separate class-key/direct-selection checks.

Instrumented container evidence disproves a proposed dynamic randc double-mark
hypothesis: dyn masks2a/2a and queue45/45 match exactly; associative1c/61 differs
from required92/92 in both2012 and2023. The dropped associative domain explains
this regression. Exact instrumented source, commands/logs and hashes are retained
under qualification/diagnosis. No runtime history changes are justified by it.

The provenance failure includes genuinely unsupported call forms that previously
only warned and were ignored. Restoring that behavior was explicitly rejected;
legal forms require real lowering/evaluation, and unsupported semantics must stay
visible until implemented. A read-only plan for package/static calls is underway.
No source edits or builds beyond the required makecheck gate have occurred.

UVM gate completed exit0:357passed,0failed,0skipped, real DPI umbrella loaded.
Frontend relocation gate then started alone as session43591. Do not inspect or
use local-install while it is hidden; await the same live session and verify
restored fingerprints afterward. Four regression-harness failures still block
qualification/integration even if this final frontend gate passes.

## Full first pass complete; focused repairs resumed

All seven gates are terminal. `qualification/first-pass-summary.json` records
legacy5179/5170pass/4fail/2NI/3EF and JSON2115/4fail, with the same four failure
names. UVM357/357 realDPI/no skips, releases15/15smoke, NFA58/58, makecheck and
all12frontend scenarios pass. All six installed-resource hashes match across
every gate and after relocation; candidate source fingerprints are unchanged.
This candidate is NOT qualified. The prior qualified baseline remainsc686a4781.

The source freeze was released only after this final verification. ABI worker now
owns the associative foreach regression and real package/type function wrapper
lowering. Runtime worker independently develops precise enum/locator reducers
and a dependency/purity plan without touching the same frontend code. No ignored
warnings, no test-oracle downgrade and no unimplemented semantics are accepted as
success. Next validation uses cheap positive/rollback checks then a coordinated
build; integration awaits corrected qualification. No new worktrees, commits,
merges, or remote actions occurred during this batch.

## Post-batch repair implementation and cheap baselines

`run-repair-regressions.py` extracts the unchanged exact four failing entries
from the real manifests and runs the legacy/JSON harnesses serially.
`repair-regressions-before.json` confirms0/4 in each on the frozen first-pass
binary with stable hashes. No expected output or failure list was changed.

ABI worker removed the accidental associative early rejection and implemented
qualified package/type function resolution through original-call wrappers.
Stateless nonautomatic support required further review: return variables can
retain state through self-reads, missing-path assignments, or partial writes.
The implementation must prove an unconditional whole-result assignment and reject
retained-result reads; dedicated package-static negatives are being added. This
conservative proof does not claim arbitrary static-function definite assignment.
Qualified-call positive checks cover repeat success and same-object late rollback.

The second worker implemented selected fixed-array reductions in the existing
reduction block. State-array tests check slice mapping, signed sums, iterator
shadowing and rollback. Root requested a separate active-rand receiver test to
match the provenance case; state-only coverage cannot substantiate that behavior.
No new coordinated build has run yet. Broad qualification remains failed with
four errors until repaired and revalidated.

## Qualified/reduction first build validated

`qualified-reduction-build.log` and install log completed0.
`qualified-reduction-first.json`:186/188 with stable artifacts. State and active
selected-array reductions pass numeric/shadowing/signed/rollback assertions.
All three static return-state negatives pass their focused purity diagnostics.
Qualified package/type calls compile but the combined fixture fails runtime with
Z3 “operator is applied to arguments of the wrong sort”; runtime repair is active.

`repair-regressions-qualified.json`:3/4pass in both exact harnesses. Both
associative state-foreach edition cases and randc container transactions now
pass. Remaining provenance diagnostics are enum.next and five locator size forms;
package/type functions and selected sum no longer cause compiler diagnostics.
The fresh remaining compiler log is preserved as repair-provenance-qualified-errors.log.

Ten newly validated edition cases (two reduction shapes and three purity-negative
shapes) were promoted, bringing focused registrations to142; the exact permanent
harness replay is running as qualified-reduction-permanent. Frontend and runtime
agents are implementing enum capture and the sort correction in parallel with
separate source ownership. No full-suite rerun or local integration occurred.

`qualified-reduction-permanent.json` completed: legacy142/142 and JSON142/142,
zero failures/skips/expected failures, stable artifact hashes. Diff-check passes.

## Qualified arithmetic and enum captures validated

The planner previously parsed unsubstituted v:N:W result tokens through a Boolean
fallback, causing an ill-sorted arithmetic term before calls could be scheduled.
It now creates width-correct fresh bitvectors only under an explicit planner flag;
actual solve parsing rejects raw captures. Existing missing/XZ substitution errors
remain enforced. Enum next/prev uses normal elaboration, exact builtin purity and
metadata handling; receiver/count dependencies are retained. Count tests start at
99, constrain2, and assert both next/prev results after changing external state.

`enum-slot-build.log` and install log completed0. `enum-slot-first.json`:190/190
with stable artifacts. `repair-regressions-enum-slot.json`:3/4pass each harness.
The remaining provenance diagnostics are the five locator size forms; its prior
package/type/enum/selected-sum errors are gone. The multidimensional foreach item
still warns ignored and must be implemented as well. Exact remaining errors are
in repair-provenance-enum-slot-errors.log.

Qualified-call and enum-step regressions were promoted in both editions, making
146 registered cases. The enum-slot-permanent harness replay is running. Existing
workers now own separate frontend sections for actual fixed-array locator counts
and multidimensional foreach, with real numeric/rollback tests. No integration or
new broad qualification claim is made.

`enum-slot-permanent.json` completed: legacy146/146 and JSON146/146,
zero failures/skips/expected failures and stable hashes. Diff-check passes.

## Locator/foreach implementation: isolate existing runtime capability

The preceding goal turn made concrete progress: enum/call semantics validated and
registered. New root source reducer locator-fixed-integral-count.sv requires an
active array [2,7,9,4] to yield count2 and preserve all values on contradictory
retry. Its paired beforeJSON records the current focused unsupported size error.

A separate locator-fixed-member-control.sv shows fixed object-array foreach
members are still dropped by frontend lowering, with paired numeric failures.
This does not establish that the solver lacks the operation: root traced the
qmelem graph path through constraint_object_element_, which already supports
fixed property-array slots. Backend-only isolation inserted explicit qmelem
constraints into emitted VVP and correctly solved active child x values3/4.
locator-fixed-member-backend-isolation.json records exact replacement, hashes,
commands and output. This deliberately injected test is NOT source-language
support evidence; it proves the existing runtime operation can be reused.

ABI worker owns locator helpers/call lowering and any necessary legacy qmelem
adjustments. Wide worker owns the fixed PEIdent index emitter and foreach branch;
no overlap with the call helpers. Foreach review also identified the need to
support omitted iterator dimensions and avoid duplicate soft constraints from
iterating skipped dimensions. No combined build has occurred for this increment.

## Locator/foreach source review before combined build

The previous goal continuation made implementation and baseline-evidence progress; the intervening user docket question was answered from the live roadmap (185 rows, including the embedded pipe in M4B-7). No compiler qualification claim follows from that count.

Two existing implementation agents were reused. Cross-review accepted row-major fixed integral indexing and foreach traversal, including skipped and trailing omitted dimensions. IEEE 1800-2023 12.7.3 and the paired 2017 text remain the authority for omitted-dimension behavior. The adjacent fixed class-array element member path now emits existing graph-backed qmelem rather than dropping the constraint.

Root review caught raw integral locator predicates being summed instead of Booleanized; the worker replaced the term with the existing conditional IR and added zero/nonzero and iterator/property collision witnesses. IEEE 1800-2017/2023 7.12.1 requires Boolean matching. Root added locator-fixed-active-member-count.sv, whose installed baseline fails compilation in both editions, to distinguish active child-field solving from merely reading state. Further review is checking multidimensional integral iterator carriers and explicit inline identifier-list provenance before the coordinated build.

The expanded focused runner includes the new positive semantic witnesses without relaxing diagnostics or rollback assertions. These are pending candidate execution, not qualified features. Two worktrees remain; neither is eligible for retirement. No new worktree, clone, remote publication, or integration occurred.

## Locator/foreach combined checkpoint: 210 focused and 166 permanent

The serial locator-foreach build/install succeeded. `semantic/locator-foreach-first.json` proves 210/210 paired-edition cases with unchanged installed hashes. The original permanent set passed 146/146 in each harness. Ten new shapes were promoted as twenty edition cases in both main manifests and focused manifests; `locator-foreach-promoted.json` proves 166/166 legacy and JSON with stable installed artifacts and no failures/skips/expected failures.

The exact broad-regression replay remains 3/4 in both harnesses (`repair-regressions-locator-foreach.json`). `sv_randc_constraint_provenance` now reports three unsupported terminal locator forms at lines99,102,135, instead of five: scoped-static receiver, selected iterator pure receiver method, and chained locator result. The multidimensional foreach warning is removed by actual numeric-tested semantics. A remaining class-key associative foreach warning at line124 is now visible. Root isolated it in `foreach-assoc-class-key-member.sv`: both editions compile with an ignored-constraint warning and fail the exact numeric runtime oracle. The fixture also contains fresh-state and failed-solve rollback assertions for the eventual repair. This is a documented failure, not support.

No expensive full suite was repeated with a known regression. The first full L64 batch remains failed and preserved. No integration/commit or remote publication occurred. The two existing lower-model workers are reused on scoped-static and chained locator paths, with coordinated frontend ownership; the root isolated associative key semantics. Full mission and current blocker remain active.

## Remaining receiver review and associative key baseline

The preceding goal turn was progress: one combined build, 210 passing focused cases, twenty newly registered edition cases, and 166/166 permanent results in each harness. The current source has additional unbuilt scoped-static and chained-locator changes. Root review required the chained outer iterator to use symbolic dense filtered-queue indices and a sibling lexical scope, not the original fixed-array index or the inner predicate's lexical context. The worker corrected both and added a nonzero-bound/filter-gap/collision witness.

Root also rejected an unchecked scoped-static purity bypass: identifier selectors could conceal side-effecting calls, and iterator-rooted reads alone did not prove absence of active random aliases. The worker restricted the current state-wrapper proof to direct non-rand integral members with recursively pure operators. `purity-scoped-locator-index-fail.sv` pins the hidden-selector rejection; `locator-scoped-active-alias.sv` records valid but still unsupported active-alias behavior as a gap, not qualified semantics. Selected methods must resolve and invoke the actual implementation, so root's `locator-selected-method-state.sv` returns a different object and changes its state between solves.

`remaining-provenance-before.json` records paired baselines for those three source forms and the associative class-key member fixture. The latter now includes two distinct keys imposing contradictory results, followed by key deletion and rollback checks; the installed checkpoint still warns that the constraint is ignored and fails its first numeric assertion. Existing typed associative key iteration APIs and graph member resolution were identified for the worker's repair. No source or library substitutions are acceptable.

### Associative key integration review (unbuilt)

The worker implemented dedicated assocforeach/qkeymember IR using actual object-key enumeration. Root review caught and requested repair of a double-consumed closing parenthesis, accidental rejection of existing nonclass associative loops, and early state sampling when the key aliases an active random child. Those fixes are now in source; graph key fields use the existing intern/scalar-property reference path. Bare unsupported key-handle use cannot emit an unexpanded ordinal token.

Root added `foreach-assoc-active-key-alias.sv` (old key bias0, active child bias6, required result7, rollback), extended the state-key fixture with conflicting keys, deletion, and empty-map vacuity, and added `locator-chained-duplicate-handles.sv` (three occurrences of one object must count3). Paired installed baselines are preserved in `locator-key-alias-before.json`; these new candidate cases have not yet been run.

The selected receiver method worker is continuing a real vertical slice: reconstruct concrete iterator receivers, evaluate the actual chosen method and returned object, and preserve purity/member dependencies. A coherent source pause was requested before the next combined build. No compiler build or broad suite ran during this review interval; the last installed qualified focused checkpoint remains210/210 and166/166 permanent per harness.

## Locator/key rebuilt checkpoint: 222/228 focused, 176/176 permanent

The first locator-key build stopped on missing iterator-context fields and two LineInfo argument mismatches. The worker corrected those integration errors, and locator-key-rebuild/reinstall completed successfully. Installed artifacts then remained unchanged through focused, repair, and permanent runs. `locator-key-first.json` records222/228: selected-method state, scoped-static count, and selected-method purity witness each fail both editions at the generic unsupported size path. The purity witness does not yet reach the intended checker, so it remains failing rather than accepting the generic rejection as implementation evidence.

All chained count, dense-index/sibling-shadow, duplicate-handle, class-key state, and active-key alias cases passed. These five shapes were promoted to ten permanent edition cases without changing their oracles. `locator-key-permanent.json` records the original166/166 per harness; `locator-key-promoted.json` records176/176 per harness, no failures/skips/expected failures, stable artifact hashes.

The exact broad replay remains3/4. Its current fresh compiler log (`repair-provenance-locator-key-errors.log`) has unsupported locator lines99/102 and a false randc-in-soft key-shadow rejection at124, plus an ignored scoped-specialization method expression at153. The class-key worker fixed the separate lowering-time randc provenance walk and added `foreach-assoc-soft-key-shadow.sv`; that correction is not yet built. The receiver worker is tracing actual parser shapes for the generic size failures, and the second worker independently reviews wrapper correctness. The focused runner now contains230 edition cases pending the next coherent build. No full suite, integration, remote publication, or new worktree occurred. The full failed L64 batch remains preserved.

## Receiver normalization and scoped-static unroll checkpoint

The prior goal turn was progress (build, numeric/purity tests, and ten then six registered passing edition cases), not a blocked or no-progress turn. The receiver-shape build completed and focused results improved to228/230: actual selected methods, OTHER-object returns, purity rejection, and assoc soft-key shadowing passed. Selected method, soft-key shadow, and method-side-effect CE cases were promoted; both permanent harnesses passed182/182.

Review of dependency concerns was grounded in IEEE 1800-2023 18.5.11 (paired2017 function-constraint rule): function arguments establish implicit priority; a no-argument method's body reads must not introduce invented ordering. Root added locator-selected-method-noarg-state.sv, proving pre-solve receiver state, refreshed next-call state, and rollback in both editions. The existing method-member branch restricts the final member to non-rand state; explicitly active returned-member alias support remains a separate gap.

Scoped static locator admission initially reached ordinary elaboration's unsupported partial row. The worker instead unrolled the remaining fixed dimension, reconstructed fully selected scoped element members, and reused purity-checked state slots. scoped-unroll-build/install succeeded; scoped-unroll-first.json is232/234 stable (only specialized static method/member remains ignored). Scoped-static count, noarg-body-state, and indexed-selector CE rejection were promoted; scoped-unroll-promoted.json proves188/188 in each permanent harness, stable, no failures/skips/expected failures.

The exact original4 replay now compiles all cases but remains3/4 because the provenance golden stream historically expected an ignored package-enum warning; the current stream instead exposes ignored scoped-specialization method/member at153. The golden has NOT been changed to accept the moved warning. The method worker corrected its actual explicit scoped-PEIdent receiver shape and added a dedicated path; this is unbuilt. Root's scoped-method-sideeffect-fail.sv extends the purity oracle for it.

The existing ternary_base_type_ok at156 is another actual ignored expression, now isolated by conditional-class-member-static-type.sv (common base field7, derived hidden randc field19, active selector, rollback). Its initial baseline is preserved; the current witness uses an8-bit hidden randc field to isolate member binding from the unrelated32-bit randc cap. The worker is implementing proper common/static member binding with symbolic conditional selection rather than eager state capture or derived-name rebinding.

A fresh pinned unmodified UVM1.2 pick_sequence probe passed (scoped-unroll-uvm12.json): compile/runtime0, UVM_PICK_SEQUENCE_PASSED, all four artifacts and source-tree hashes identical before/after. This is a concrete UVM witness, not whole-release qualification. No broad full suite, integration, remote publication, or worktree creation occurred.

## Conditional member semantics: native solving and guarded validity

The preceding goal turn was progress: rebuilt receiver fixes, 232/234 focused evidence, 188/188 permanent cases per harness, and the fresh pinned UVM probe. Current review rejected the first conditional-member proposal because synthesizing a function wrapper would create an artificial selector-priority stage. An ordinary member selected by a conditional must retain bidirectional constraint solving. The worker replaced that proposal with native hselectfield IR using the common-base member ID and existing handle/object graph identities. No method-name special case or eager selected-field sampling is acceptable.

Root strengthened conditional-class-member-static-type.sv: the selector is unconstrained, result3 must select the base handle and result7 the derived handle, repeated in both directions, while the derived hidden randc field remains19; failed solves restore state. conditional-member-bidirectional-before.json proves paired installed failures.

Native null/invalid branch handling initially accumulated global hard side constraints. Root and independent review required expression-local validity instead: global constraints must not leak out of enclosing conditionals or turn a soft preference into a hard condition. The existing state-false implication parser already skips its consequent, so root refined the inactivity witness to an outer state-controlled ternary, whose branch error pruning otherwise would not remove the proposed global side constraints. Graph X/Z errors must follow the same scope as nongraph failures. IEEE1800-2023 18.5.12 constraint guards and8.4 null-handle rules were checked locally; null member access is illegal, while a guarded-away expression must not create an evaluation failure.

New pending witnesses: conditional-member-inactive-branch.sv (disabled outer ternary, selected valid branch with unselected null), conditional-member-active-fields.sv (active child fields3/7, bidirectional selector, rollback). conditional-members-guard-active-before.json records paired compile-with-ignored-warning/runtime failures. They are included in the expanded focused runner without accepting warnings as success. The worker is correcting validity propagation and removing obsolete nonrand restrictions left over from the rejected wrapper approach. The specialized static method AST patch remains ready and unbuilt.

A separate qualification-corrected/run_gate.py was prepared under the existing L64 evidence directory; pending.json explicitly says not_started. The failed first full batch is preserved. No gates/builds/integration/publication or worktree creation ran during this review interval. The installed validated checkpoint remains unchanged.

## Final focused repair qualification and full-batch freeze

conditional-native build/install completed; focused242/242 passed with stable artifacts. Original provenance now compiled and ran with a completely empty compiler diagnostic stream and PASSED output. Only its historical ignored-warning gold remained different. After verifying the clean stream and paired numeric/purity evidence for the repaired constructs, root removed that obsolete warning from legacy and JSON golds; no warning was accepted or substituted.

Independent review found lost signedness on the final conditional-field Z3 ite and asymmetric logical definedness for a deciding right operand. Root reproduced both in conditional-sign-rhs-before.json (paired compile0/runtime1), then the worker repaired signed tagging and compositional logical validity. conditional-final-build/install succeeded. conditional-final-focused.json proves246/246 with stable artifacts; repair-regressions-conditional-final.json proves4/4 in both exact harnesses, no failures/skips/expected failures. Seven additional positive/negative shapes were promoted to fourteen permanent edition cases. conditional-final-promoted.json proves202/202 in both harnesses, stable, no failures/skips/expected failures.

Both implementation workers were instructed to freeze compiler/test/source edits and builds. Root is freezing this uncommitted candidate for the corrected full L64 qualification in qualification-corrected, preserving qualification as the failed first pass. The same seven gates will run; integrated and JSON serialize their shared test logs, and frontend runs alone last. No local integration is claimed until the full batch and review are complete.

## Corrected full batch: two diagnostic regressions remain

All seven corrected gates are terminal. qualification-corrected/summary.json records legacy5249 total/5242 pass/2 fail/2 NI/3 EF; JSON2185 ran/2 fail; UVM357 pass/0 fail/0 skip with real DPI; NFA58 pass; release15 smoke passes; make check pass; frontend12 scenarios pass. All735 snapshotted source/test/docs files, tracked diff, and six installed artifacts matched the candidate throughout. This batch remains unqualified; the original failed batch is preserved.

Both remaining failures are unchanged negative fixtures: sv_class_fixed_array_reduction_fail lost its precise unselected array rank diagnostic; sv_randc_constraint_provenance_fail gained a redundant generic unsupported diagnostic after its required soft/randc error. Two existing workers reviewed root causes; one is implementing minimal diagnostic corrections and the other reviews. Golds remain unchanged. Freeze is released only after the terminal snapshot audit. Multi-prefix reduction review confirmed an early guard excludes more than one prefix, so no wrong-row execution was established; legal a[i][j].sum() remains an explicit feature gap. No local integration or remote publication is claimed.

## Diagnostic repair passes; conditional nested-handle review reopens runtime

The two minimal diagnostic changes built successfully. Exact unchanged negatives pass2/2 in each harness and focused246/246 pass with stable artifacts. Reverse-applying just these edits reconstructs the previous elaborate.cc hash exactly; only installed ivl changed among six artifacts. qualification-diagnostics/delta-audit.json preserves this evidence. Integrated replay passes5249 total/5244 pass/0 fail/2 NI/3 EF plus VPI108, negative149, runtime15, copyout6, exports66. Snapshot735files, tracked diff, and six artifacts are stable.

Independent transaction review found no concrete rollback or argument-priority defect. Conditional validity review instead proved an accepted-source runtime defect: `(pick ? left.child : right.child).x`, with pick forced1 and right null, compiles cleanly in both editions but fails from an inactive null-owner read. conditional-handle-read-review preserves source/log hashes and exact commands; indexed-handle attempts were rejected and are not runtime evidence. Integrated replay is terminal, freeze released, and the planned JSON replay is deferred to avoid running another broad gate over a known defective candidate. The runtime worker is distinguishing branch-dependent access errors from malformed metadata, with another worker expanding paired tests and reviewing. L64 remains unintegrated and unqualified.

## Nested-handle branch validity repaired and promoted

Root expanded the focused baseline to250 edition cases:246 pass and exactly four new nested branch/scopes outcomes fail, with clean compiles and stable binaries (nested-handle-before.json). The worker classified handle-read failures explicitly: runtime access failure can follow branch validity; malformed/static metadata remains an unconditional diagnostic. Optional classification outputs preserve other handle-reader callers. Independent review found no concrete defect.

Serial nested-handle build/install succeeded. nested-handle-after.json proves250/250 stable. Root malformed-operand controls prove4/4 before and after: an invalid property ID and malformed handle token remain unconditional errors even on the inactive branch. Two positive shapes were promoted to four paired permanent cases; nested-handle-promoted.json proves206/206 in each harness. Original4 and diagnostic2 exact regressions pass in both harnesses, stable; stateforeach runtime invariants15/15 pass. New cases check both arm directions, refreshed reads, selector/result rollback, inactive outer implication, and optional soft validity.

Current runtime differs from the prior fully exercised candidate. No exact-current seven-gate qualification, integration, remote publication, or complete IEEE/UVM support is claimed. Previous batch evidence remains intact.

## Repaired candidate broad qualification freeze

Root rechecked focused250/250, permanent206/206 each, exact original4/4 and diagnostic2/2 each, malformed4/4 and stateforeach15/15. Existing workers frozen. qualification-nested-handle will exercise all seven gates against current artifacts; prior failed and diagnostic-only batches remain preserved. Integrated precedes JSON; frontend runs last alone. No worktrees created, and the two-tree audit found no eligible tree for retirement.

## Final seven-gate qualification

qualification-nested-handle/summary.json proves all seven gates pass against the same six installed artifacts. Legacy5253 total/5248 pass/0 fail/2 NI/3 EF; JSON2189/0; UVM357/0/0 with real DPI; NFA58/0; release15 smoke passes (complete and baseline_valid); frontend12 scenarios; make check. Integrated auxiliary checks pass VPI108, negatives149, stateforeach15, copyout6 and covergroup exports66. All749 snapshotted source/test/docs files and tracked diff stayed unchanged. Manifest audit verifies103 edition pairs registered once in each main/focused harness. Final freeze is released.

Earlier failed batches are preserved and remain failed. The grammar build records in typed-dependencies-build.log report14 shift/reduce and5 reduce/reduce conflicts; subsequent changes did not edit grammar. Canonical Clause18 remains PARTIAL, with L64 evidence and residual operand/capture gaps recorded explicitly. No edition-specific semantic difference is claimed, and no whole IEEE1800.2/OpenTitan/Caliptra qualification follows from these tests. The reviewed patch is ready for local commit/integration.

## Local integration checkpoint

Semantic source, permanent tests, and scoped canonical documentation committed as4bc02c51b. The staged-diff check exposed one trailing space in the new staged-state-size fixture; follow-up0c6d5994a removes only that whitespace. Full main-to-HEAD diff check passes. Local main was fast-forwarded fromcc66db23e to0c6d5994a with an ancestor check and expected-old-value ref update. Compiler/runtime did not change after qualification. No remote push or merge occurred.

Two worktrees remain: the active campaign and the retained dirty controlling checkout. None was created or retired. Canonical graph refresh is pending because its retained checkout must first be safely brought to clean current main; this feature worktree must not update the shared graph. The continuous campaign returns to concrete blocker selection; full standards, IEEE1800.2, OpenTitan/Caliptra and formal objectives remain active.
