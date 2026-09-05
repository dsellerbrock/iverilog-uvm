# CURRENT WORK — continuation state

## Current execution policy — 2026-09-04

The user explicitly raised the per-process CPU guard from 45 to **300 seconds
(5 minutes)**. Use `../evidence/arm64-tooling/resource-runner` or inherit
`ulimit -t 300` for new compiler/simulator sweeps. Native ARM64, Homebrew
Bison 3.8.x, absolute worktree `local-install/bin` first on PATH, and no RSS
or output-size ceiling remain required. Earlier 45-second measurements below
are historical evidence; they do not set the current limit.

## Active increment — 2026-09-04 — dynamic root randomize callbacks

Branch `agent/randomize-hooks-after255-arm64-20260904` is based on
`167e8bf5d` (draft PR #255). The validated installed build4 fixes dynamic
root callback dispatch and root callbacks on `randomize(null)`, with exact
2017/2023 regressions, including the reviewed escaped-identifier correction.
Ten focused executions and the fresh complete build4 gate pass: legacy
4557/4562 (0 failed), JSON 1451/0, VPI 103/103, negative 149/0, runtime
invariants, and real-DPI UVM 355/0/0. Compiler fingerprints stayed fixed.
Both censuses completed with unchanged binaries and inputs. OpenTitan has
203 PASS (210 previously): seven zero-traffic xbar runtime passes now fail,
and Darjeeling-main changes from timeout to the same time-zero randomization
failure. All compile classifications are unchanged. ADC completes with the
prior isolated replay's metrics and full output-line multiset. Summed debt
2223 → 2222 is solely diagnostic interleaving, not semantic progress.
Caliptra remains 52 PASS / ICARUS_GAP 0, all 105 jobs unchanged. Its invalid
first attempt omitted a baseline harness wrapper; the corrected full rerun
is recorded separately. Enabled-member callbacks and simultaneous random
object graph constraints remain next requirements. Native and Claude CLI reviews are complete
and reconciled; both conditional Claude questions were resolved using the
actual label matcher, a forced-fallback probe and both IEEE editions. See [the callback session record](session_logs/2026-09-04_dynamic_root_randomize_hooks.md).

## Previous validated increment — 2026-09-04 — hierarchical state foreach

Branch `agent/xbar-foreach-after254-arm64-20260904` now contains the xbar
foreach implementation in the retained worktree. It preserves selected-owner
identity, guard errors, typed indices, target lookup and failed-solve state.
The prerequisite nested-queue assignment defect is also repaired. Focused
legacy and JSON checks pass 14/14. The final full gate passes legacy
4551/4556 (0 failed), JSON 1445/0, VPI 103/103, negative 149/0, runtime
invariants and real-DPI UVM 355/0/0. Caliptra remains 52 PASS / ICARUS_GAP 0
with all 105 jobs unchanged. The complete OpenTitan census has 210 PASS (+15), no lost PASS, and summed
debt 2223 (20 actual warning removals plus 2 diagnostic-interleaving count
artifacts). All eight xbar compile rows and seven runtime rows became PASS.
ADC and Darjeeling-main census timeouts did not reproduce in isolation:
116.449s and 109.677s respectively, with matching baseline runtime metrics
and diagnostic/output evidence. Raw census counts are retained. All xbar
smokes report zero scoreboard items, so meaningful DV traffic remains an
open issue despite the compile/constraint progress.
See [the implementation and validation record](session_logs/2026-09-04_hierarchical_state_foreach.md).
The previous validated compiler contains this increment, so the checkpoint
counts below remain the historical pre-xbar checkpoint.

## Latest validated checkpoint — 2026-09-04

PR #254 is merged as `bafc8b5b4`. The final reviewed compiler checkpoint
`1819a3ee5` passes legacy ivtest (4537/4542, 0 failed), JSON/VVP (1431/0),
VPI (103/103), negative tests (149/0) and real-DPI UVM (355/0/0). The full
300-second censuses preserve all 530 OpenTitan classifications (195 PASS)
and all 105 Caliptra classifications (52 PASS, ICARUS_GAP 0). OpenTitan's
summed debt count is 2245; eight constraint warnings disappeared, with three
offsetting line-count artifacts from interleaved undefined-macro warnings.

See [the September 4 session log](session_logs/2026-09-04_unqualified_parenless_method_and_frontier_retriage.md)
for per-core comparisons and raw diagnostic checks. Full application DV is
still incomplete. The hierarchical foreach increment above is validated;
next investigate why the unmodified xbar smokes finish with zero scoreboard
items before treating runtime census PASS as meaningful DV completion.

## Active increment — 2026-09-02 — parameterized VIFs, recursive containers, and typed mailboxes

Worktree:
`iverilog-uvm-param-vif-specialization-after250-arm64-20260901`

Branch `agent/param-vif-specialization-after250-arm64-20260901` starts exactly
at `origin/main` `dcd3f8fc1e293ffd4ecd4c559273be5f904fe5e4`. The current
increment is a shared IEEE 1800-2017/2023 6.22, 7.4-7.10, 13.5,
15.4.5-15.4.9, and 25.5/25.7/25.9 type-and-runtime refinement.

The parameterized-interface path now reconstructs the evaluated interface
specialization rather than reusing default parameter values, preserves a
per-physical-instance carrier for interface-local nominal declarations, and
uses the bound VIF instance to select the matching method candidate. The
evidenced result types are interface-local enums, unpacked records, and class
handles. Scalar VIF-task `output`, `inout`, and `ref` formals select and write
back through the same physical candidate. Modport identifier imports reuse the
interface declaration signature; full prototypes are checked with the
6.22.1 matching relation, not the weaker 6.22.2 equivalence relation. Selected
modport actuals retain their concrete parameter specialization when connected
to an unqualified interface formal. Malformed modport prototypes also unwind
their parser state within an item and at a physical-file boundary.

The container path carries a recursive Q/D/A declaration layout through VVP.
It preserves container kind, nested child layout, full queue-bound metadata,
deep value-copy independence, and root provenance after assignment or method
mutation. Fixed unpacked-array elements may now themselves be queues, dynamic
arrays, associative arrays, or the recorded nested Q/D/A compositions; the
selected fixed slot remains the receiver and its index is evaluated once.
Strict new-image metadata is validated before scheduling while the legacy
image path remains accepted.

The typed-mailbox path now uses semantic type equivalence for statement and
expression calls to `put`, `get`, `peek`, `try_put`, `try_get`, and
`try_peek`. Retrieval nodes can retain a real elaborated l-value and the target
runtime can capture that l-value before a blocking operation. Direct scalar,
string, real and object destinations, packed selects, properties, fixed words,
and queue/dynamic-array elements are represented; successful try calls write
back and an empty try leaves the target unchanged. The mailbox reducer gate is now
CLOSED: a ref-output target naming storage inside an object is captured through
the property path whichever way its owner is spelled, which removed both the
"unsupported indexed mailbox ref-output signal shape" refusal and an internal
vvp assertion (`vvp_fun_signal_object_sa: recv_vec4 not implemented`) that an
accepted program could reach. A signal-backed associative element
(`mi.get(assoc[key])`) still fails to create or write its entry; that is
pre-existing on mainline and remains open.

Measured focused evidence currently available:

| Gate | Result |
|---|---:|
| New nominal-result/task-copyback VIF rows, legacy | **8/8** |
| New nominal-result/task-copyback VIF rows, JSON/VVP | **8/8** |
| Exact-main compiler on the same rows, legacy | **0/8** |
| Exact-main compiler on the same rows, JSON/VVP | **0/8** |
| Repaired recursive-container regression cluster | **13/13** |
| Interface-port-array cluster | **4/4** |
| Fixed-array-of-container 2017/2023 pair | **2/2** |
| Modport parser recovery | **verified against exact golds** |
| Typed-mailbox final reducer gate | **closed — 2/2 rows** |
| Paired VIF specialization focus gate | **68/68 legacy + 68/68 JSON/VVP** |
| OpenTitan array-of-containers focus gate | **18/18 legacy + 18/18 JSON/VVP** |
| Full legacy ivtest sweep | **0 failed** |
| Full JSON/VVP ivtest suite | **0 failed** |
| UVM suite (`.github/uvm_test.sh`) | **355 passed, 0 failed** |

These are focused mechanism results, not a broad-regression or application
closeout. The full legacy, JSON/VVP, negative, VPI, real-DPI UVM, OpenTitan,
and Caliptra replays remain pending for this increment. Therefore the last
recorded application baselines remain OpenTitan **192 PASS of 530 classified
rows** and Caliptra/Adams Bridge Icarus **53/105** versus Slang **54/105** in
the static assertions/no-assertions/synthesis census. No application count has
been advanced by this branch yet.

The exact clauses, reducer names, implementation boundary, and next gates are
recorded in
[`session_logs/2026-09-02_parameterized_vif_recursive_containers_typed_mailbox.md`](session_logs/2026-09-02_parameterized_vif_recursive_containers_typed_mailbox.md).

## Active increment — 2026-09-01 — virtual-interface functions and inherited class parameters

Worktree:
`iverilog-uvm-opentitan-vif-function-after248-arm64-20260901`

Branch `agent/opentitan-vif-function-after248-arm64-20260901` starts exactly
at `origin/main` `99bf9c549` (the PR #248 merge). Production checkpoints
`5efa20856` and `e41b32d14` are pushed. The compiler and VVP runtime use native
ARM64 tools, Homebrew Bison 3.8.x, and the shared 45-second CPU guard without a
memory ceiling.

This increment implements a bounded IEEE 1800-2017/2023 8.13, 9.2.2.2.1,
13.4, 13.5, and 25.9 cluster:

- A value-returning call through an unparameterized virtual interface records
  every compatible concrete interface-function candidate. VVP selects the
  candidate from the receiver's bound instance and evaluates that candidate's
  typed argument/default row before entering the method.
- Packed, real, string, class-handle, queue, and dynamic-array returns retain
  their result stacks. Statement-position discarded results still execute,
  and a null receiver terminates loudly.
- Declaration-scoped defaults may read interface members and earlier formals.
  Automatic calls use private frames. Static-formal setup uses an
  invocation-local typed overlay until the complete selected row is ready,
  then commits to shared storage before the body executes; body recursion
  retains the shared-static semantics required by 13.4.2.
- Function-body reads reached through a constant interface-port-array element
  contribute to `always_comb` sensitivity without emitting declaration-only
  delay, supply, or resolver nodes into the target netlist.
- The VVP object stack grows on demand instead of asserting after 32
  object-valued actuals.
- Unqualified value parameters inherited from a specialized base class are
  resolved nearest-superclass-first after local lookup. This fixes the legal
  OpenTitan use of `CyclesWithNoAccessesThreshold * 2` as an actual for
  `virtual_interface.wait_clks(...)`.
- VIF task statement rows retain the existing compile-progress policy for
  an actual that already failed frontend elaboration: only that store is
  skipped. Expression-position VIF functions remain strict, and a missing
  actual is no longer misreported as a formal-direction failure.

The paired `sv_inherited_class_parameter_vif_task` reducer is red on the
separately built exact main compiler: it warns twice that the inherited
parameter is unresolved and observes 0 instead of 160. The branch resolves
160 under both `-g2017` and `-g2023`. The complete focused legacy and JSON/VVP
lists each pass **31/31**.

The final native-ARM64 OpenTitan closeout classifies all 530 unmodified rows at
clean revision `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`:
192 `PASS`, 20 `DEBT`, 104 `FAIL`, 16 `RUNTIME_FAIL`, 157
`DEPENDENCY_ONLY`, 35 `UPSTREAM_INVALID`, and 6 `SETUP_FAIL`. The lane totals
are RTL 93 pass / 153 dependency / 18 upstream-invalid; SVA 99 pass / 6 debt /
2 fail / 4 dependency / 17 upstream-invalid; UVM compile 12 debt / 46 fail /
3 setup-fail; and UVM runtime 2 debt / 56 fail / 16 runtime-fail / 3
setup-fail. `DEBT` is not counted as a pass.

The first stable replay had exposed one direct branch regression in UART: the
branch retained main's two unresolved-parameter warnings and added two VVP
target diagnostics, turning a warning-only compile into `FAIL`. The follow-on
removes both the diagnostics and the underlying warnings. Relative to that
replay, UART is the only final row delta: its compile row advances
`FAIL` to `DEBT`, and its runtime row advances `FAIL` to `RUNTIME_FAIL`. It
reports a separate null virtual-interface method call near 497,725,923 ps and
continues through the UVM sequence's 504,840,923 ps marker. The setup-ready
UVM compile-through count is 12/58 versus 8/58 at the recorded mainline
application baseline and 11/58 before this follow-on; no clean OpenTitan UVM
compile or runtime pass is claimed.

The raw concurrent runtime campaign recorded 300-second timeout classifications
for ADC and TL-agent while the canonical UVM sweep loaded the host. Exact
single-row replays through the required 45-second CPU guard restored both to
their prior `RUNTIME_FAIL` classifications. The raw campaign remains preserved;
only those two guarded classifications are used in the final aggregate.

The post-fix frozen Caliptra/Adams Bridge static census completed all 105
manifest jobs (420 compiler invocations) in 86.361 seconds with no timeout:
52 `PASS`, 1 `DEBT`, 51 `SHARED_SOURCE_OR_CONFIG`, and 1
`SOURCE_ORDER_DEBT`. Icarus reaches 53/105 in each assertions,
no-assertions, and synthesis lane versus Slang 54/105. Every classification,
outcome, diagnostic, and manifest-metadata field matches the prior final and
available clean post-#241 mainline census. This is a frozen RTL/SVA/synthesis
manifest census, not a complete Caliptra DV/UVM run.

The authoritative post-fix compiler sweep is also clean: 1,320 JSON/VVP entries
ran with zero failures (17 NI and 45 expected-fail), legacy SV is 2,242/2,242,
negative tests are 149/149, real-DPI UVM is 354/354 with zero skips, and VPI is
103/103. The shared `ivtest/vsim` harnesses were run sequentially.

Boundaries remain explicit. Dynamic VIF function output/inout/ref arguments,
fixed-unpacked arguments or returns, complete parameterized-interface and
modport specialization, and synthesis lowering are not claimed. The full
mechanism, application evidence, and invocation notes are in
[`session_logs/2026-09-01_virtual_interface_functions.md`](session_logs/2026-09-01_virtual_interface_functions.md).

## Active increment — 2026-09-01 — class instance constants and constructor order

Worktree:
`iverilog-uvm-opentitan-instance-const-after247-arm64-20260830`

Branch `agent/opentitan-instance-const-after247-arm64-20260830` remains based
exactly on `origin/main` at `1a877231f` (the PR #247 merge). The compiler and
VVP runtime were rebuilt with native ARM64 tools and Homebrew Bison through the
shared 45-second CPU guard with no RSS ceiling.

This increment implements a bounded IEEE 1800-2017/2023 8.19/19.5 subset:

- Parsed procedural `for` initializers now have a stable ordinary assignment
  carrier. A mutable signal retains the direct `NetForLoop` synthesis path;
  class-property, other nonsignal, and const-signal l-values use ordinary
  assignment elaboration before the loop, preserving typing and const-write
  legality.
- Constructor-flow analysis authorizes only corresponding-constructor
  instance-constant writes, requires definite initialization before a referring
  embedded-covergroup constructor, and rejects initializer/construction pairs
  in one loop or `fork...join_none` region. A header initializer is outside the
  repeated region; body and step share it. Literal-false, omitted or direct
  literal-true, normal, `continue`, `break`, and return channels are modeled.
- Literal and already-evaluated class-parameter repeat counts are observed
  without speculative expression elaboration or duplicate diagnostics.
  Lexical formals, locals, and explicit or pinned wildcard imports shadow class
  parameters; unary minus retains the literal width and signedness.
- VVP records the authorized property ID and enforces at most one executed
  assignment per object. Malformed `%prop/const/init` metadata fails cleanly
  rather than underflowing or accepting a wrapped property index.

Paired permanent evidence includes `sv_class_instance_const_flow`, the
conditional/loop/fork/for-step runtime-failure families,
`sv_class_instance_const_static_fail`,
`sv_covergroup_class_const_bin_ranges_fail`, the repeat-count flow/shadow/probe
families, `sv_class_static_const_for_init_fail`, and the malformed VVP runner.
A separately built clean-main compiler accepts the isolated static-const
for-header reducer in both editions; this branch rejects it with the exact
ordinary const-write diagnostic.

Final native ARM64 gates:

- focused legacy **44/44** and JSON/VVP **44/44**;
- full SystemVerilog **2,212/2,212**;
- full JSON/VVP **1,290 entries, 0 failed**;
- negatives **149/149**, VPI **103/103**, malformed VVP **1/1**;
- real-DPI UVM **354/354**, 0 failed, 0 skipped;
- nine positive synthesis loop reducers plus one negative sentinel, all with
  the ordinary mutable-index `NetForLoop` path retained.

The focused unmodified OpenTitan `lowrisc:dv:rv_timer_sim:0.1` UVM core at
clean revision `7a3ad34b` improves from FAIL to **DEBT**: setup and compile
return 0, hard errors are 0, and the four former instance-constant range drops
are absent. Seventeen unrelated loud debt diagnostics remain, so this is not a
runtime or application pass. The pinned ARM64 Python 3.13/FuseSoC toolchain was
used. `util/regtool.py` also regenerates the UART register RTL byte-for-byte
identically to the unmodified checked-in sources.

The remaining boundary is deliberately explicit: nonliteral constant-condition
proof and exhaustive constructor control flow are not claimed. Next after this
increment lands is the statically diagnosed Ubuntu Actions repair requested by
the user; no VM or emulator is authorized.

## Active increment — 2026-08-30 — virtual interfaces, dynamic event lists, and left-`$` queue slices

Worktree:
`iverilog-uvm-opentitan-syntax-event-frontiers-after245-arm64-20260828`

Branch `agent/opentitan-syntax-event-frontiers-after245-arm64-20260828` was
created from `origin/main` at
`affd74d41` (the PR #245 merge). At this documentation checkpoint its nine
production/test commits run from `b5692b918` through `00e3d74dd`. The compiler
and VVP runtime were rebuilt with native ARM64 tools and Homebrew Bison 3.8.x
through the shared CPU guard without an RSS ceiling.

This branch closes three bounded, edition-paired language clusters:

- IEEE 1800-2017/2023 25.9 and Syntax 25-3: both `virtual iface` and
  `virtual interface iface` are accepted as data types in the evidenced legal
  contexts. Parse-form provenance records that the type is virtual rather than
  an ordinary interface-port type and follows arrays, forward and package
  typedefs, concrete type-parameter defaults/actuals, and `type(expression)`
  using lexical lookup. Module/interface/program ports, interface items, and
  union members are rejected; compilation-unit/package/module/block variables,
  declaring-for variables, unpacked-struct members, qualified class properties,
  and task/function/method arguments and returns remain legal.
- Clause 25.9 logical equality and inequality: `==` and `!=` accept `null`, an
  equivalent virtual interface, or a same-definition concrete interface
  instance in either operand order. VVP compares the bound scope and interface
  definition, so separate wrappers around one instance compare equal without
  changing ordinary class pointer identity. The focused positive includes
  constant selection from an unqualified one-dimensional interface-instance
  array, same-type conditional handles, rebinding, null, different instances,
  and an instance whose name matches its interface type.
  Width probing and comparison elaboration share a non-evaluating lexical
  preflight so a local scalar array can shadow an outer interface-instance
  array instead of being silently rebound. Different interface definitions,
  scalars, two concrete instances, `===`/`!==`, and `==?`/`!=?` are exact
  errors.
- Clause 9.4.2, with preserved leaf semantics from 6.17, 14.10/14.12/14.14,
  and 15.5: every leaf of a mixed explicit `or`/comma event list is prepared
  once. A dynamically selected VIF member or class-property expression may be
  mixed with ordinary signals, named events, a run-time-selected event-array
  element, and direct/default/global clocking events. Each dynamic family gets
  an independently cancellable one-shot waiter. The isolated join-any helper
  resumes the statement once and unlinks every loser without cancelling a
  detached child owned by the user's process. Retaining the prepared netlist
  expression prevents repeated side effects and duplicate diagnostics while
  special leaves still use their complete single-leaf lowering.
- Clause 7.10.1: the r-value spelling `q[$:hi]` is parsed and lowered without
  evaluating the source twice. `$` is the last index of the live, already-
  evaluated queue; `hi` is evaluated once. Exact and above-last upper bounds
  select the final element, while a lower/reversed or X/Z bound and an empty
  source produce an empty result. The result is an unbounded queue even when
  the source is bounded. Integral, logic, real, string, class-handle, nested-
  container, selected class-property, static-property, method, and unevaluated
  type-query paths are pinned; nested values copy while class handles preserve
  identity.

The focused native checkpoint is:

| Gate | Result |
|---|---:|
| Virtual-interface context/comparison/extension legacy | **22/22** |
| Virtual-interface context/comparison/extension JSON/VVP | **22/22** |
| Chapter-9 statement/event focus legacy | **14/14** |
| Chapter-9 statement/event focus JSON/VVP | **14/14** |
| New left-`$` queue rows, legacy | **6/6** |
| New left-`$` queue rows, JSON/VVP | **6/6** |
| Full legacy | **2,188/2,188** |
| Full JSON/VVP | **1,266 ran, 0 failed** (**1,249 pass, 17 unchanged NI**) |
| Negative diagnostics | **149/149** |
| VPI | **103/103** |
| Canonical real-DPI UVM | **354/354** |

Homebrew Bison 3.8.2 reports 533 shift/reduce and 1119 reduce/reduce conflicts,
versus 535/1119 on the merge base. Canonical conflicting-state item-core
comparison found no unintended terminal-action changes; the two removed shift
conflicts came from redundant `protected virtual` method-only shortcuts that
the shared class-item dispatch now subsumes.

Boundaries remain explicit. Parameter overrides on virtual-interface types
still warn because specialization identity and nondefault member widths use the
interface defaults. Modport selection and parameter specialization are not yet
complete components of virtual-interface comparison type identity. IEEE
1800-2017/2023 23.6 requires an instance-array selection in a hierarchical name
to be a constant expression. The separately registered unqualified
one-dimensional run-time bit-select therefore records an intentional
application-compatibility extension, not 25.9 conformance; hierarchical and
multidimensional run-time dispatch are not claimed. Slang 11 accepts the core
25.9 positive in both editions and rejects that extension, but accepts the
case/wildcard VIF operators that 25.9 does not list; Icarus retains its
normative diagnostics. A single event-expression leaf that itself mixes VIF and
class/ordinary dependencies remains a focused error, and the older root/key/
index mutation and compound snapshot boundaries are unchanged. A left-`$`
queue slice is implemented only as an r-value: assignment to `q[$:hi]` is a
loud `sorry`, and `$` as the base of an indexed `+:`/`-:` selector remains
separate work. Nonqueue receivers and nonintegral explicit bounds fail loudly.

The full compiler regressions above are attributed to this checkpoint. No
OpenTitan or Caliptra application matrix was replayed, and no application
pass/fail counts or source-frontier movement are changed by this branch.
Durable mechanism and invocation detail is in
[`session_logs/2026-08-30_virtual_interface_event_list_queue_slice.md`](session_logs/2026-08-30_virtual_interface_event_list_queue_slice.md).

## Active increment — 2026-08-28 — positional container conversion and call boundaries

Worktree:
`iverilog-uvm-opentitan-array-conversion-after244-arm64-20260828`

Branch `agent/opentitan-array-conversion-after244-arm64-20260828` was created
exactly from `origin/main` at
`00c21f05c6cf818a4d626237e8c2301d7379518b` after PR #244 merged. Production
code and permanent regressions are committed and pushed as `674e38b5f`. The
active compiler and VVP runtime were built with native ARM64 tools and
Homebrew Bison 3.8.x through the shared CPU guard without an RSS ceiling.
OpenTitan, Caliptra, Accellera UVM, and generated application source remain
unmodified.

The normative audit separates four related boundaries:

- IEEE 1800-2017/2023 7.6 permits a fixed unpacked array, dynamic array, queue,
  or slice to be assignment compatible with another such value when their
  slowest-varying element types are equivalent (and a fixed destination has
  the same element count). Only that slowest-varying dimension may differ in
  array kind; every faster-varying dimension is part of the element type and
  must be equivalent. A queue or dynamic-array target is resized to the source
  count and receives elements in left-to-right order.
- Under 6.24.1, an assignment-compatible explicit cast has the value that a
  temporary of the cast type would receive by assignment. If ordinary
  assignment compatibility does not apply and the types are bit-stream types,
  6.24.1 directs the cast to 6.24.3. The evidenced integral-container subset
  packs index 0 at the MSBs and accepts an element-width change only when the
  complete source stream fits the destination exactly.
- Clause 13.5 copies input/inout values into a native subroutine and copies
  output/inout values back on return. Clause 13.3.2 initializes an automatic
  task's output storage to its declared default on every invocation, while a
  static task's ports retain their values between invocations; 13.4.2 supplies
  the corresponding function lifetime rule. An empty body does not erase
  argument evaluation, dispatch, frame, or copy-back effects.
- Clause 7.10.5 applies the declared bound after every ordinary bounded-queue
  write, discarding excess tail elements and warning. A bit-stream cast is
  different: 6.24.3 requires a size mismatch to fail once detectable, so it
  cannot use ordinary bounded-assignment truncation to make an oversized cast
  appear successful.

The implementation now carries both source and destination type provenance
through assignment, explicit casts, function/task arguments, aggregate
builders, and VVP lowering. Equivalent-element queue/dynamic-array transfers
materialize a fresh value of the destination or actual's declared kind before
it can be hidden by an enclosing assignment or method call. Direct signals,
class properties, selected/nested properties, conditional and function
results, input and output/inout copy boundaries, queue methods, assignment
patterns, nested containers, and unpacked-struct members use this common
destination-typed path. Nested container and unpacked-struct values are copied
independently; class elements remain shared handles; struct prototypes and
passive container metadata are retained; and a side-effecting destination
selector is evaluated once.

Explicit positional-container casts now have their own frontend marker.
Assignment-compatible casts, including same-kind casts and cross-kind `real`
containers, use the ordinary typed-copy path. Non-assignment-compatible
integral queue/dynamic-array casts use a strict pack/unpack marker: the tested
byte-queue to word-dynamic-array round trip preserves index-zero/MSB ordering,
materializes independent destination storage, and carries a 64-bit queue bound
without wrapping through the older unsigned queue API. A source bit count not
divisible by the destination element width, a result larger than a bounded
queue, or the existing bounded runtime-width guard terminates with a stable
VVP error and a nonzero status. The conditional-source path checks both arms.
Nested associative-array element comparisons include key type and wildcard
metadata instead of accepting the coarse internal queue representation.

Native task output queue and dynamic-array formals are no longer copied in
from the caller. An
automatic output therefore begins empty on every call, while a static output
retains its private prior value and is copied independently to successive
actuals. The pre-existing caller-shape copy-in is now confined to imported DPI
open-array output formals, where the foreign routine needs the actual's
descriptor. Task and nonvoid-function output/inout actuals are validated as
lvalues and require equivalent positional-container elements in both
directions; the ordinary OpenTitan assignment extension does not leak into
formal binding. Calls with empty native bodies are retained so input side
effects and untouched output defaults remain observable. DPI queue/dynamic-
array output acceptance remains an interoperability boundary rather than a
native-language conformance claim.

The follow-on array audit closes the corresponding direct fixed-array slice
gap in value-returning calls. `PECallFunction` now recognizes a legal constant
one-dimensional slice before scalar rvalue elaboration, retains its backing
signal plus canonical storage window in `NetEArraySlice`, and applies the same
fixed shape/element and output-lvalue checks as a whole-array actual. Native
fixed formals copy elements left-to-right even when formal and actual ranges
run in opposite directions. Automatic pure outputs start from their element
defaults, static outputs retain their formal storage, and copyback changes
only the selected actual words. DPI open formals activate the slice's declared
bounds for Annex-H access while the C view remains numeric-indexed; the C
regression never reads an output formal's unspecified initial contents.
Malformed `%slice/push`, `%load/arr/dar/slice`, and
`%store/arr/dar/slice` images recover without an assertion or partial store.
Multidimensional and class/property slice actuals remain explicit follow-on
work rather than part of this direct-signal subset.

The VVP text contract keeps the legacy `%queue/to/darray` spelling, adds
`%container/to/queue`, and adds typed object-collection splice forms with an
out-of-line prototype descriptor. Keeping that descriptor outside
`vvp_code_s` preserves the common instruction at three machine words (24 bytes
on this ARM64 build). The loader validates exact arity, element and stream
encodings, 64-bit stream queue bounds, and resolved unpacked-struct prototypes
before scheduling. Runtime fallbacks remain non-asserting and keep their stack
contract if an internally constructed record is malformed.

OpenTitan's `spi_agent_cfg::swap_byte_order` still motivates one deliberately
narrow interoperability extension. Its ordinary assignment between
`logic [7:0][$]` and `bit [7:0][]` is not IEEE element equivalence. Only an
ordinary blocking cross-kind queue/dynamic-array assignment between non-enum
packed `bit`/`logic` elements of equal nonzero width and signedness is widened;
same-kind assignment, initialization, delayed/nonblocking assignment, formal
or ref binding, width, signedness, and enum identity remain strict. Conversion
to a 2-state destination maps X/Z to zero under 6.11.2. Slang
11.0.448+e222e7dc0 rejects the four paired state-changing assignments in both
editions and its VCS compatibility mode. No VCS, Questa, or Xcelium executable
was available, so this is labeled an interoperability extension rather than a
commercial-simulator differential or standards claim.

The final native-ARM64 checkpoint and focused slice evidence are:

| Gate | Result |
|---|---:|
| Chapter-7 focused legacy | **79/79** |
| Chapter-7 focused JSON/VVP | **72 ran, 0 failed** |
| Direct container conversion/runtime/parser invariants | **42/42** |
| Negative diagnostics | **136/136** |
| Full legacy SystemVerilog | **2,151/2,151** |
| Full JSON/VVP | **1,229 ran, 0 failed** |
| VPI | **103/103** |
| Canonical real-DPI UVM | **354/354, 0 failed, 0 skipped** |
| Fixed-slice focused legacy | **24/24** |
| Fixed-slice focused JSON/VVP | **21/21** |
| Real-DPI fixed-slice reducer | **1/1** |
| Hand-written slice-opcode recovery invariants | **7/7** |

The canonical real-DPI UVM gate completed in 664.82 seconds wall time and
loaded the real DPI umbrella without the `UVM_NO_DPI` fallback. The earlier
isolated real-DPI reducer established the original runtime-kind defect:
rebuilt previous main passed 9/10 and failed only
`queue_to_dynamic_runtime_kind`, while the destination-typed branch passed
10/10 at that checkpoint.

An authentic FuseSoC 2.4.5/Edalize 0.6.3 OpenTitan replay gathered before the
later cast and subroutine hardening used clean revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` and covered `spi_device_sim`,
`spi_host_sim`, Darjeeling, and Earlgrey. The former
`spi_agent_cfg.sv:139`/`:143` mismatch has zero occurrences in all four current
logs, which reach independent later frontiers at
`spi_device_scoreboard.sv:1177`, `spi_host_env_cfg.sv:36`, or
`spi_host_driver.sv:40`. Recorded prior red counterparts prove removal for the
Darjeeling and Earlgrey top-chip closures. The older standalone
`spi_device_sim` and `spi_host_sim` logs stopped earlier and do not establish a
red-to-green transition for that diagnostic. All four remain **FAIL**; this is
an unblocked-source-path result, not four OpenTitan passes. No final full
61-target OpenTitan census and no new Caliptra replay belong to this commit
yet.

Boundaries remain explicit. General recursive 6.24.3 bit-stream types are
recognized conservatively, but aggregate/class/structure shapes outside the
integral positional-container carrier still follow legacy lowering and are
not claimed here. The direct strict cast path preserves a queue bound above
`UINT_MAX`, but ordinary queue signal/method storage still uses the older
unsigned maximum in several paths, so this is not general 64-bit queue-bound
support. The mixed-state extension still requires a bare direct-identifier
RHS. Full IEEE clauses 6, 7, and 13, complete OpenTitan and Caliptra DV/runtime
flows, formal-source elaboration, and commercial-simulator parity remain open.

## Active increment — 2026-08-27 — typed string concatenation and selected-byte conversion

Worktree:
`iverilog-uvm-opentitan-typed-string-after242-arm64-20260827`

Branch: `agent/opentitan-typed-string-after242-arm64-20260827`, created from
`origin/main` at
`6bfe64ce55e399b8154b5fe95e5fbbdf89a6f911` after PR #242 merged. All
validation used the worktree-local native-ARM64 compiler and runtime through
the shared resource runner. OpenTitan, Caliptra, and Accellera UVM sources
remain unmodified.

This increment implements the evidenced IEEE 1800-2017/2023 6.16, Table 6-9,
and 11.4.12.2 typed-string concatenation subset. A concatenation now receives
its complete string assignment context for parameters, fixed string arrays,
and procedural assignments. String expressions and literals, nested groups,
string-returning methods, and parentheses-free zero-argument static functions
retain string type through width probing, elaboration, constant folding, and
VVP lowering. All-literal groups are converted by a string context but retain
packed-integral behavior outside it. Uncast integral-only and mixed
string/integral operands are focused errors; the check is operator-local, so a
conditional arm or a whole-expression `string'(...)` cast cannot hide a real
string expression mixed with an uncast integral expression. An explicit cast
of the integral operand is the supported conversion and removes null bytes.
Constant and run-time integral string replication is pinned, including the
form `{repeat_count{{"A", "B"}}}` in a direct string target, a whole string
cast, and both comparison operand orders. A nonintegral multiplier is
rejected, and a string replication or string-expression concatenation cannot
be assigned to an integral target. In a string context, a zero multiplier
produces the empty string and the replicated operand is evaluated exactly once,
just as it is for a nonzero multiplier.

Parameterized-class template elaboration now preserves the declared-type
provenance of a direct formal, local, or property concat operand. If that type
is an unresolved class type parameter, the generic body defers the hard
Table 6-9 decision; each concrete specialization is checked normally. The
paired positive path covers formal and property operands specialized as
`string`, while a dedicated paired negative requires `#(int)` to remain a
focused mixed-operand error.

Review hardening removes the former `count < (1<<20)` cutoff from newly
generated string replication rather than replacing it with another arbitrary
compiler limit. A legal variable repeat now produces and checks all
**1,048,576 bytes**. New images use explicit signed or unsigned VVP opcodes;
the unsuffixed opcode retains its old signed and copy-boundary semantics for
textual-image compatibility and has an independent pinned fixture. The typed
runtime diagnoses a negative signed count, X/Z count, or value wider than its
index representation before returning the empty result. Allocation is
otherwise bounded by the string implementation's representable size. A host
allocation exception is converted to a controlled diagnostic in the runtime,
but is not forced by a deterministic regression.

One legacy spelling remains deliberately narrower than general uncast integral
acceptance. The `br_gh800`-style literal-only group containing at least one
string literal plus integral literals is retained as a compatibility extension.
It does not admit an integral variable, select, call, or other expression into
a concatenation that contains a true string expression.

The implementation also repairs an adjacent runtime value defect. An explicit
`string'(source[index])` formerly passed a selected integral value through the
string-container evaluator and produced an empty string. VVP now evaluates the
selected vector once and converts it to the expected one-character string.

Built-in string method typing now matches the declared result categories for
data objects and constant string parameters: `len`, `compare`, and `icompare`
return `int`; `getc` returns `byte`; the four integer conversions return
`integer`; `atoreal` returns `real`; and `toupper`, `tolower`, and `substr`
return `string`. The same typing reaches a method called directly on a nested
concatenation. Each built-in arity is checked before lowering: the zero-, one-,
and two-argument families emit one hard diagnostic instead of silently
ignoring an argument, synthesizing a missing argument, or continuing into a
malformed call. Argument-type checking is not generalized by that arity work;
the pre-existing acceptance of `s.compare(65)` remains a bounded residual.
Review also changed constant string-parameter evaluation to consume semantic
raw bytes instead of rendered display text. Empty strings, nonprinting bytes,
and literal backslash/quote data now retain their actual length, character,
case-conversion, and substring values.
Variable indices and comparison operands on a constant parameter receiver now
lower normally instead of being rejected as nonconstant. Constant string
comparisons fold on semantic bytes in both operand orders. String repetition
uses an allocated VVP index word, preserving a bounded queue's live maximum
index while its RHS is evaluated.

Direct `string[index]` remains byte-typed under the IEEE rules, and Slang 11
rejects it as a direct string-concatenation operand. OpenTitan uses that
spelling in commercial-simulator-targeted source, so the compiler admits only
a final 8-bit select whose underlying object has string type. This is a narrow,
documented compatibility extension, not an IEEE claim. Ordinary vector selects
and integral-returning functions still require an explicit string cast. VCS,
Questa, and Xcelium were not run. The selected character remains `byte` outside
that concatenation exception; applying a string method such as `.len()` to a
direct, parameter, struct, or class-property selected character is now a hard
type error rather than dispatching the method on the unselected whole string.

Final native-ARM64 validation is clean: focused legacy **23/23**; focused
JSON/VVP **24/24**; full legacy **2,083/2,083**; full JSON/VVP **1,161
entries, 0 failed** (**1,144 executed/pass plus 17 recorded NI**); negative
diagnostics **136/136**; VPI **103/103**; textual VVP compatibility **6/6**;
and canonical unmodified real-DPI UVM **354/354**, 0 failed, 0 skipped.

The expanded current positive reducer is red against the clean canonical
`origin/main` compiler at
`6bfe64ce55e399b8154b5fe95e5fbbdf89a6f911`: it emits two internal
typed-expression diagnostics and reaches the `par_string` assertion (exit
134). The final compiler runs that exact source to `PASSED`. A separate
minimal type-parameter control passes on both main and the final branch; the
review regression was the intermediate branch's premature generic-body error,
which is now pinned by the specialization positive and concrete negative.

An earlier same-branch unmodified OpenTitan Darjeeling and Earlgrey top-chip
replay, performed before the final generic-class deferral hardening, moved
their former internal typed-concatenation counts from **10/18** to **0/0**.
Both now first report the independent queue-versus-dynamic-array context
mismatch at `src/lowrisc_dv_spi_agent_0.1/spi_agent_cfg.sv:139`. Each then
traverses a much larger later diagnostic path before the compiler segfaults
and emits no VVP image. The tops still do not elaborate. No new full 61-target
OpenTitan matrix has been run; the last matrix remains **8 DEBT / 50 FAIL / 3
SETUP_FAIL / 0 PASS** and is not reclassified by these two replays. The final
narrow deferral change has not been replayed across those application tops.

Caliptra was not rerun. Its last audited 105-job static census remains **52
PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT / 0
ICARUS_GAP**: 52 clean and 53 debt/shared-source cases. It remains static
compile/elaboration/synthesis differential evidence rather than full DV
runtime.

The shared IEEE 1800-2017/2023 zero-multiplier and once-only operand-evaluation
behavior is implemented. Slang 11 rejects the standalone zero-replication
reducer with its narrower rule that zero replication is permitted only inside
an enclosing concatenation; that exact disagreement is recorded rather than
used to override the direct IEEE interpretation.

Bounded residuals remain explicit. A direct string element of a fixed-size
unpacked signal array retains the correct two-character value but reports
`.len()` as 1; the same probe works for dynamic arrays, queues, and a fixed
array inside a class property. The pre-existing compiler also accepts
`s.compare(65)`, the reverse mixed comparison `{8'h41} == s`, and a non-static
method called as `C::f`, all of which Slang rejects. A static zero-argument
class function without parentheses retains its string type in the supported
run-time concatenation, but its use in a constant `localparam` concatenation is
still rejected by the current branch. These cases are not included in the
implemented subset. The next independent OpenTitan source frontier is the
`spi_agent_cfg.sv:139` context mismatch; the later broad-graph compiler
segfault also needs a separately reduced witness. Full mechanism, regressions,
and application evidence are in
[`session_logs/2026-08-27_opentitan_typed_string_concatenation.md`](session_logs/2026-08-27_opentitan_typed_string_concatenation.md).

## Active increment — 2026-08-26 — associative-array assignment patterns and fixed-prefix leaves

Worktree:
`iverilog-uvm-opentitan-dynamic-with-after239-arm64-20260826`

Branch: `agent/opentitan-dynamic-with-after239-arm64-20260826`, created exactly
from `origin/main` at
`a2ebad3b4a654d968da8c31454b408835e1591b1` (merged PR #239). All work and
validation used native ARM64 tools. OpenTitan remained clean at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`; Caliptra remained clean at
`bd31614182fb56e55578f48086a10ded650434fd`, with Adams Bridge at
`e59eba955eac2a1adcb059f250641ede78e304be`. OpenTitan, Caliptra, and Accellera
UVM sources were not modified.

The normative audit used the ignored local IEEE 1800-2017 and IEEE 1800-2023
PDFs, SHA-256
`2b94a960a93c0bd2cf10305e6c05c57ba865e6fdcd20dcbbd42319f82177ce31`
and
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`,
against 7.4, 7.9.11, and 10.9.1. Paired `-g2017`/`-g2023` evidence now covers
associative assignment patterns with explicit constant string, integral, and
enum keys plus at most one non-entry fallback `default`. Duplicate converted
keys, duplicate defaults, nonconstant keys, X/Z integral keys, and
incompatible key/value categories are errors. Default state does not insert an
entry or change `size()`.

Pattern items evaluate exactly once in lexical order into a fresh typed value;
the destination is replaced only after the complete right-hand side exists.
Whole maps, queues, nested maps, and unpacked-struct values copy independently,
while class elements preserve handle identity. The same lowering covers
declaration and procedural assignment, typed/cast patterns, arguments,
returns, conditional arms, and OpenTitan's enum-to-string, enum-to-queue,
CSRNG nested-map, and fixed-outer-array forms. Direct signal-backed
fixed-unpacked prefixes ending in integral/string/real-valued associative leaves
retain the full product of declared fixed dimensions and separate the selected
outer slot from the trailing associative key for whole-map and direct-entry
reads, writes, and map methods. Explicit/default real reads, direct stores,
sibling isolation, and constant/variable outer selectors use that same selected
map receiver. Ascending, descending, nonzero, negative, and mixed
multidimensional ranges remain independent. Every fixed dimension is checked
before flattening, so an invalid, X, or out-of-range component cannot alias a
valid sibling. Stores still evaluate address and RHS side effects once but make
no write; reads and map methods likewise cannot touch the sibling. The raw VVP
guard also rejects malformed
`%aa/set/default/v` width metadata without consuming its source stacks or
resizing storage.

This is bounded support, not complete clause-7 or clause-10 closure. Packed
bit/part/member and other deeper/partial entry tails, property/member and
struct-nested receivers, fixed-prefix queue/dynamic-array leaves,
fixed-prefix maps with class-handle/container/struct values,
associative-array-typed parameters, broader receiver/context combinations,
randomization, `ref`, VPI, and synthesis remain unsupported, unclaimed, or loud.

Current native-ARM64 validation is clean:

- paired associative/default focus: legacy **54/54**, JSON/VVP **54/54**;
- canonical legacy ivtest: **4,127 pass, 0 fail, 2 NI, 3 expected fail**
  (**4,132 total**);
- full JSON/VVP: **1,017/1,017**;
- bundled VPI: **103/103**;
- negative diagnostics: **136/136**; and
- canonical unmodified real-DPI UVM: **354/354**, with 0 failed and 0 skipped.

Bison 3.8.2 reports no new parser-conflict debt against the exact parent. The
main parser remains at 535 shift/reduce and 1,115 reduce/reduce conflicts over
201 states, normalized descriptor SHA-256
`b96fa4bf669e73f14ed8748e864e8b3f4cdfbdc61b45ec6d5cab66a7e6946bc8`.
The VVP parser remains at 14 shift/reduce and 5 reduce/reduce conflicts over 9
states, with byte-identical raw reports and normalized descriptor SHA-256
`f9d4b8ef1d5ab7f29b5ca7ae9bce2ac780960055409d4b6ff3f47e3dcacf978d`.

The fresh OpenTitan UVM compile census completed all 61 targets in **53.60
seconds** with **8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS**, zero timeouts, and
no resource-limit signals. No former exact refusal, generic unsupported
associative-pattern diagnostic, or associative-literal syntax diagnostic
remains anywhere in the matrix. The affected cores now stop on independent
language or provider frontiers; this is compile/elaboration/code-generation
evidence, not OpenTitan simulation-pass coverage. Native ARM Python 3.13.15
and FuseSoC 2.4.5 were also used to run `regtool.py` for UART.
`uart_reg_pkg.sv` and `uart_reg_top.sv` were byte-for-byte identical to the
checked-in RTL, with SHA-256
`106f8da3d41f8cfe585a58e91c251e23e76c81d25956cb751f61644023dfa01b`
and
`8c40c957fbd7c1155f58d2c7696340b7ea6b82c2b0626ec684463f991538ae27`.

OpenTitan evidence is outside the repository at
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/opentitan-assoc-pattern-postaudit-after239-arm64-20260826T210149-0600/`.
The matrix JSON, Markdown, and runner-log SHA-256 values are
`f230258ce602775f16ea75bc0450d497bce2df506ec207a765da10fed0be49ab`,
`53d73fd3035cbf81d86e3dc7ac06dbb7bc976cc85dd35ffd7f65cf9bda4eb92e`,
and
`0b7d7cb3962f3a7b866a952d21ad54b103e4b893676df0a155d5767db5f480e0`.
The captured compiler driver and engine SHA-256 values are
`8c018567b9364148779d3351df9b8fe25a469abbaf2a0cd7e7f9538d0801db37`
and
`de0f462acd9d864ff6c9305902ba5d009ab9b31903ef701cfcacc6e3c61a0336`.
Canonical regression evidence is at
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/assoc-pattern-postaudit-after239-arm64-20260826/`;
the legacy and JSON/VVP logs have SHA-256
`7c78283ae6e82d94a9ea9b54105bf2839479b9bfbfc3ab2aeedc2f2dd5d59d94`
and
`299a0b0a1612e1cb01f8c9f936f4091001cdd5c85799b11b64cbb6225337187a`;
the VPI and real-DPI UVM logs have SHA-256
`ee6a19505b08f9d717493a686d8b99a6b2f14996da1e78d2975b048ab07f2588`
and
`121c32f9c6375af0d67e50159cae85b5054c1d2488044cf2e3fa553e3a8b5b9a`.

The frozen Caliptra static census completed 105 jobs and 420 compiler
invocations in **58.30 seconds**. Icarus passes **53/105** in each assertions,
no-assertions, and synthesis lane versus Slang **54/105**. Classification is
**52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT /
0 ICARUS_GAP**; the sole Slang advantage remains the known `csrng_raw_wrap`
source-order debt. This is static compile/elaboration/synthesis differential
evidence, not full Caliptra DV runtime. Evidence is at
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-assoc-pattern-postaudit-after239-arm64-20260826T210409-0600/`;
the result JSON, Markdown, and console-log SHA-256 values are
`2438c1cd0930bffe915f0537c9213ddcc80761491105d66e85222d3589181d41`,
`706b0e94b68be66fe45ea4d0885fd5f380d643d5471e96078d0bed53112959a7`,
and
`bc56323336a888e0ea2b96bd7d569e6890fa77db1c10ebc9bf86dba2aa9496a7`.
Full design, test, tooling, and boundary detail is recorded in
[`session_logs/2026-08-26_opentitan_associative_assignment_patterns.md`](session_logs/2026-08-26_opentitan_associative_assignment_patterns.md).

The next independent OpenTitan frontier is the valid `for` initializer used by
two full-chip cores that mixes an enum declaration with an integer declaration,
including a package-qualified enum variant. Slang accepts the exact sources in
both selected editions. This is a separate parser mechanism and belongs on the
next fresh branch after this increment is merged.

## Active increment — 2026-08-26 — bounded dynamic-cross topology and final hardening

Worktree:
`iverilog-uvm-opentitan-dynamic-cross-after238-arm64-20260826`

Branch: `agent/opentitan-dynamic-cross-after238-arm64-20260826`, created
exactly from `origin/main` at
`1e4df2813c1200b8cadfe6a9a3e28cb3451dadab` (PR #238 merge). OpenTitan and
Caliptra sources remain unchanged.

The direct IEEE 1800-2017/2023 clause-19 audit is implemented for a bounded
cross subset. Integral open arrays coalesce duplicate and overlapping ranges
into one logical bin per distinct resolved value. Fixed arrays partition
ordered matching occurrences, put the remainder in the final nonempty bin,
and apply ignore/illegal carving after distribution without redistribution.
Per-covergroup-object cross plans freeze fixed, transition, and constructor-
dependent logical-bin dimensions after constructor capture. Sampling forms the
Cartesian product of every matched source identity. Overlapping named normal
bins count independently but at most once each per sample; routing precedence
is `illegal` over `ignore` over normal independent of declaration order; and an
illegal cross match leaves its source coverpoints and unrelated crosses intact.

The implemented selection IR covers automatic products,
`binsof`/named-`binsof`, `intersect`, and Boolean `&&`/`||`/`!`; the focused
support claim directly exercises conjunctions and cross `iff`. IEEE 1800-2017
keeps uncovered automatic bins. IEEE 1800-2023
`option.cross_retain_auto_bins` defaults to 1. A covergroup-level assignment is
the default for its crosses, and a cross-local assignment overrides it;
coverpoint and every `type_option` placement are errors. The implemented subset
supports constant values and rejects the declaration in 2017 mode. With a
constant zero, the runtime suppresses automatic bins when any explicit normal,
ignore, or illegal record exists—even if its selector is empty—while a cross
with no explicit record remains automatic. The focused retention reducer
directly pins the normal-bin and no-explicit-bin cases, inherited covergroup
defaults on fixed and dynamic crosses, cross-local disable and enable
overrides, and empty ignore/illegal declaration presence. The LRM evaluates
option expressions at covergroup construction, but that constructor/per-
instance expression path is not yet implemented. The option is definition-
only; dedicated procedural-write and repeated-assignment negatives remain to
be pinned.

Current native-ARM64 local compiler/runtime validation is clean:

- paired clause-19 focus: legacy **20/20**, JSON/VVP **20/20**;
- full legacy ivtest: **4,103 pass, 0 fail, 2 NI, 3 expected fail**
  (**4,108 total**);
- full JSON/VVP: **993/993**, after building and installing the
  optional native-ARM64 `tgt-fpga` target required by two `-tfpga` entries;
- negative diagnostics: **136/136**;
- bundled VPI: **103/103**; and
- canonical unmodified real-DPI UVM: **354/354**.

The final full native-ARM64 OpenTitan UVM compile matrix at clean
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` completed 61 targets in 47.62
seconds with **8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS**, zero timeouts, and
zero resource-limit signals, versus the previous **1 DEBT / 57 FAIL /
3 SETUP_FAIL / 0 PASS**. The DEBT targets are `adc_ctrl`, `dma`, `hmac`, `mbx`,
`pattgen`, `soc_dbg_ctrl`, `tl_agent`, and `uart`; seven moved FAIL→DEBT and
`tl_agent` retained its earlier DEBT classification. Both the exact former
constructor-dependent-cross-drop diagnostic and the generic cross-drop
diagnostic occur zero times. The remaining failures are independent parser,
provider, clocking, dynamic-`with`, and isolated elaboration frontiers. This is
a compile matrix: it did not run simulations and contains no clean application
or runtime pass.

Evidence is outside the repository under
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/opentitan-dynamic-cross-final-after238-arm64-20260826T183204-0600/matrix`;
the result JSON SHA-256 is
`b97844e5b327b98a251e3c03f15e6939e827c0f849a88cfd538f1334b388fa55`
and the engine SHA-256 is
`599a85f0c35730e151227abfd6c698cf9bc8556c50f8f6b70ccf0aa728e1cff1`.
Design, test, timing, and native-tool invocation detail is in
[`session_logs/2026-08-26_opentitan_dynamic_cross_topology.md`](session_logs/2026-08-26_opentitan_dynamic_cross_topology.md).
The full canonical real-DPI UVM regression is now **354/354** on the current
tree. The final Caliptra static census completed 105 jobs and 420 compiler
invocations in 52.33 seconds: Icarus is **53/105** in each assertions,
no-assertions, and synthesis lane versus Slang **54/105**. Classifications are
**52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT /
0 ICARUS_GAP**; the sole Slang advantage is the known `csrng_raw_wrap`
source-order debt. Evidence is
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-dynamic-cross-final-after238-arm64-20260827T003032Z`
with result JSON SHA-256
`857e7b5a97ca35810ac21258e0367f63bd53766ee5d3ca2f65639e09e8add9fd`.
This is static compile/elaboration/synthesis differential evidence, not full
Caliptra DV runtime.

Clause 19 remains **PARTIAL**. Constructor/per-instance expressions for the
2023 retention option, illegal cross bins over transition terms, remaining
dynamic `with`/`matches`/set/`CrossQueueType` selection forms, source
ignore/illegal carving from dynamic-family denominators, type-coverage union,
report/VPI and normative naming detail, broader signed static range/intersect
normalization, empty trailing fixed-array-bin identity/naming, real/tolerance
coverage, and products beyond the explicit 65,536-bin topology cap remain
open.

The project direction is unchanged: selected IEEE 1800-2017 and IEEE
1800-2023 semantics come first; unchanged UVM, OpenTitan, and Caliptra are
application gates; VCS, Questa, and Xcelium are the commercial RTL/DV
interoperability targets after the IEEE text; Slang is a parser/elaboration
differential; and Verilator is diagnostic only. The frontend, scheduler, SVA,
and IR are being made compatible with an eventual formal engine, but formal is
not a current capability claim. UPF/IEEE 1801 remains deferred until the IEEE
1800 language and verification surfaces are substantially closed.

## Resume state — 2026-08-26 — typed constructor coverage and commercial direction

Worktree:
`iverilog-uvm-commercial-after237-arm64-20260826`

Branch: `agent/opentitan-commercial-after237-arm64-20260826`, created exactly
from `origin/main` at `eb68431e5937fb6a5fe6baa98ad6f3d399b924ab` before this
increment. The source-of-truth repository and clean OpenTitan/Caliptra trees
remain unmodified outside the Icarus worktree.

This increment implements a typed, per-covergroup-object construction-time IR
for the bounded integral constructor-dependent bin-range subset required by
OpenTitan's TL agent. It carries the coverpoint, source value, and endpoint
width/sign metadata through the target ABI and VVP image, evaluates each
object's range once, applies clause-19.5.7 conversion and X/Z rejection,
intersects ranges with the coverpoint domain, treats descending ranges as
empty, and preserves the duplicate-membership behavior exercised by the
focused tests. Malformed typed and legacy VVP metadata is bounded and rejected
safely. Unsupported endpoint trees, constructor-dependent `with`, and dynamic
crosses diagnose and drop the affected construct rather than silently
substituting a value. A later direct-LRM audit found that this checkpoint did
not establish—and the then-current static-bin path did not correctly
implement—the distinct-value identity of open bins, fixed-array remainder
placement, or post-distribution ignore/illegal carving. Those defects are
recorded in the active increment above rather than hidden by the 8/8 result.

The paired `-g2017`/`-g2023` focused gates pass 8/8 in the legacy harness and
8/8 in JSON/VVP. They cover the exact OpenTitan expression
`[0 : 2 << (valid_source_width - 1) - 1]`, typed wrap/shift/count behavior,
mixed widths/signs, input capture, descending ranges, duplicate fixed-bin
membership, safe `'0`, unary minus, coverpoint-domain intersection,
construction-time parent-set capture, unknown endpoints, and loud unsupported
boundaries. Raw VVP metadata tests also pin malformed type descriptors and
old-image compatibility. These are subset gates, not full clause-19 closure.

Clean serial native-ARM64 broad validation on the committed tree reports:

- `make check`: pass;
- legacy ivtest: 4,094 total, 4,089 pass, 0 fail, 2 recorded NI, and 3
  expected fail;
- JSON/VVP: 979 run, 0 fail;
- bundled VPI: 112/112;
- negative diagnostics: 136/136;
- focused metadata/options checks: pass; and
- complete canonical real-DPI UVM: 354/354, 0 failed, 0 skipped (596.49
  seconds wall).

An earlier overlapping legacy/VPI invocation was discarded because both
harnesses share `ivtest/vsim` and log names; impossible cross-test log contents
proved workspace contamination. The clean results above are serial reruns.

A native-ARM64, clean-source OpenTitan UVM compile matrix exercised all 61 UVM
targets at OpenTitan `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` with FuseSoC
2.4.5 under ARM Python 3.13.15. It completed with no timeouts and changed the
same-scope baseline from 58 `FAIL` plus 3 `SETUP_FAIL` to 1 `DEBT`, 57 `FAIL`,
and 3 `SETUP_FAIL`; there are still zero clean passes, and this matrix did not
run simulations. The sole transition is `lowrisc:dv:tl_agent_sim:0.1`: the
unmodified `valid_sources` range now compiles with zero hard errors, leaving 12
pre-existing generic UVM semantic-debt diagnostics. Of the 57 failures, 16
first-stop at dynamic-family cross metadata, 28 at parser/syntax frontiers, 8
at the missing `prim_clock_gating` provider, 3 at unresolved
`clocking_decl_assign` paths, and 2 at isolated export/hierarchical-constant
frontiers. The three setup failures are unchanged generated-file graph issues.
The earlier 18-core coverage-range count included the SVA-lane
`adc_ctrl_sva`; this UVM-only matrix contains 17 such former first frontiers,
one resolved and 16 advanced to cross integration.

Evidence is outside the repository at
`evidence/opentitan-commercial-after237-arm64-20260826/full-uvm/`; the JSON
SHA-256 is
`b52ce5d846544c88f24dba3fbd41b97522247c44567861be85a65d0d2c5b560f`.
The immediate shared OpenTitan coverage frontier is construction-time dynamic
family integration into crosses, followed by dynamic `with` and object/method-
valued ranges. Constructor `ref`/output/inout directions, broader/context-sized
endpoint expressions, dynamic ignore/illegal denominator carving, dynamic
type coverage, report/VPI detail, and 2023 real/tolerance coverage remain
explicit gaps. Unrelated parser/provider/clocking work remains larger than the
coverage cluster.

A fresh native-ARM64 frozen Caliptra census ran all 105 manifests across
Icarus +SVA, Icarus -SVA, Icarus synthesis, and Slang: 420 serial invocations,
zero timeouts, 53/105 in every Icarus lane and 54/105 in Slang. The classes are
52 PASS, 1 DEBT, 51 SHARED_SOURCE_OR_CONFIG, 1 SOURCE_ORDER_DEBT, and zero
ICARUS_GAP or SLANG_ONLY_DIFFERENCE. A job-by-job comparison against after-236
found zero changes in classification, exit/timeout state, diagnostic counts,
or compact diagnostics. Evidence is in
`evidence/caliptra-commercial-after237-arm64-20260826/`; its JSON SHA-256 is
`123e1194cd3cf5915cdcdda396f4f2f22bb1e98226fa54f247f809d67c7ab755`.
External UVMF, ARM AXI checker, and Avery inputs still prevent a full Caliptra
DV runtime claim.

The intended audited direction for this increment is: IEEE 1800-2017 and
1800-2023 are first-class selected editions; unchanged UVM/OpenTitan/Caliptra
are application gates; VCS, Questa, and Xcelium are the commercial
interoperability targets after the IEEE text; Slang is a parser/elaboration
differential; Verilator is diagnostic evidence only; a formal proof engine is
future work; and UPF/IEEE 1801 is deferred until the IEEE 1800 frontend and
runtime are substantially closed. The README, manifesto, roadmap, edition
matrices, and local-standard instructions are audited against that direction
at each checkpoint rather than self-certifying permanent consistency.

## Resume state — 2026-08-26 — declaration lifetimes, call unwind, and DPI ABI

Worktree:
`iverilog-uvm-opentitan-caliptra-after235-arm64-20260826`

Branch: `agent/opentitan-caliptra-after235-arm64-20260826`, based exactly on
`origin/main` at `a375c7b69d2f033535a112a791e7ae5384e960f5` (0 ahead / 0
behind before the pending commits).

This continuation retains the four compiler/runtime clusters exposed by
unchanged OpenTitan and Caliptra sources and closes the recorded DPI disable
protocol gap. Explicit declaration lifetimes now control
storage, initialization, VPI `vpiAutomatic`, fixed-array access, event
identity, virtual-interface dispatch, array-port context, and detached-frame
retention independently of the containing subroutine lifetime. A self-kill
from nested synchronous calls no longer rejoins already-reaped frames, and
abandoned caller-owned automatic contexts are released in exact LIFO order.
Method-local queue `.size`/`.size()` expressions now reach the constraint
solver. The recorded DPI subset now uses Annex-H scalar/result ABIs for narrow
integers, scalar bit/logic, shortreal, chandle, string, packed-vector formals,
and supported export directions, including host plain-`char` polarity and
prefixless old-image compatibility. Exported task C stubs now have the Annex
H.8.2 `int` status ABI, newly compiled imported tasks use a checked integer
acknowledgment ABI, and the runtime implements `svIsDisabledState()` plus
`svAckDisabledState()` with per-invocation state across parked C stacks.

Exact native-ARM64 validation on this branch is clean:

- serial build/install and `make -j1 check` pass;
- legacy ivtest: 4,088 total, 4,083 pass, 2 recorded NI, 3 expected fail,
  0 unexpected fail;
- JSON/VVP: 973 entries, zero harness failures;
- bundled VPI: 103/103;
- negative diagnostics: 136/136;
- scheduler UVM focus: 23/23;
- real-DPI UVM focus: 37/37;
- the process-kill reducer passes the modern and legacy call engines with
  exactly five abandoned call-site contexts released in each mode; and
- parser reports remain 535 shift/reduce plus 1,115 reduce/reduce conflicts
  across 201 states; the VVP parser reports 13 shift/reduce plus 5
  reduce/reduce conflicts across 8 states.

Separately, a fresh full real-DPI run on this branch is clean: the complete
canonical UVM harness passes 354/354 with 0 failed and 0 skipped (real
578.66s), with the real DPI umbrella loaded.

Pinned Slang 11 in IEEE 1800-2017 mode accepts 10 of the 11 new
lifetime/process sources, including the exact process-kill reducer. Its sole
rejection is fixed-array-element `force`/`release`; IEEE 1800-2017 and 2023
§§6.4 and 10.6.2 permit a reference to the selected singular integral
variable, so this is recorded as a differential-oracle disagreement rather
than copied into Icarus. No VCS, Questa, or Xcelium execution was performed;
their IEEE Annex-H task signature and disable behavior remain the practical
interoperability target, not claimed validation evidence. Verilator was not
used as a semantic or ABI oracle.

The focused unchanged Caliptra `axi_pkg.sv` + `axi_if.sv` witness at
`bd31614182fb56e55578f48086a10ded650434fd` compiles with zero diagnostics and
its VVP image loads and exits normally. This proves only package/interface
elaboration and image loading: it does not execute an AXI transaction or a
full Caliptra top. The runtime-only OpenTitan HMAC replay at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` reaches the 45-second CPU guard at
210,327,516 ps without the scheduler assertion, another assertion, UVM error
or fatal, loader failure, or crash. It remains short of the former
1,339,336,540 ps failure point and is supporting frontier evidence only; the
mainline-red exact reducers supply the red/green proof. The cleanup census
prints one residual vec4 stack entry while the externally interrupted HMAC
thread is torn down, which is guard-termination noise rather than a natural
simulation exit result.

IEEE 1800-2017/2023 §35.9 and Annex H.8.2 are now implemented for the recorded
DPI task/function subset. An exported task returns 0 after normal completion
or a disable targeting only that export, and returns 1 when an ancestor
disables the enclosing mixed-language chain. In the ancestor case the parked C
stack resumes exactly once for `svIsDisabledState()` and resource cleanup; an
imported task acknowledges with return value 1, while an imported function
calls `svAckDisabledState()`. The disabled SV export/import tails remain dead.
The runtime issues a fatal error for an incorrect task acknowledgment, a
disabled function that omits its acknowledgment, or the §35.9(d)-forbidden
attempt to call another export after entering the disabled state. Newly
compiled task calls use `%dpi/call/task/ack`; the old `%dpi/call/task` void ABI
remains loadable for normal legacy images and diagnoses a disabled invocation
because that ABI has no acknowledgment channel.

Permanent coverage is split deliberately: `m10l_dpi_disable_protocol_test`
checks normal, direct-disable, ancestor-disable cleanup, synchronous-function
acknowledgment, concurrent-call isolation, ancestor cleanup with an outstanding
branch that survived `join_any`, and a second synchronous export that disables
the caller immediately after C resumes from a parked export. The latter pins
the scheduler-owned caller and completed child through re-entry so each still
has one owning reap. Two concurrent automatic callers also verify that direct
VPI work from resumed C runs with the imported task's caller context rather
than the completed export child's context; the four cases in
`run_dpi_disable_protocol_negatives.sh` require the protocol fatals; and
`run_dpi_legacy_task_void_compat.sh` pins both normal old-image execution and
the loud diagnostic when a disabled void-ABI image has no acknowledgment
channel. This closes the
disable-handshake item, not the entire DPI matrix. Imported shortreal arrays
and legal fixed-size unpacked export formals remain loud gaps, and the
exhaustive import/export signature cross-product remains M14B-9 work. Full
OpenTitan and Caliptra application runs and matrices also remain follow-up
work; neither project source tree was modified.

Durable process-unwind detail is in
`session_logs/2026-08-26_opentitan_process_kill_trampoline.md`. Exact SoC and
full-UVM replay artifacts live outside the repository under `evidence/`.

## Resume state — 2026-08-25 — OpenTitan class events and HMAC mask path

Worktree:
`iverilog-uvm-class-event-after233-arm64-20260825`

Branch: `agent/opentitan-class-event-after233-arm64-20260825`, based exactly
on `origin/main` at `92c68dd3c0b8bb0478ec9b6de77f8645ad16c180`.

This increment fixes three compiler/runtime defects exposed by the unchanged
OpenTitan HMAC image: selected class-property event controls now retain and
filter their armed owner; strength-resolved `vec8` nets retain exact Preponed
history; and a run-time index into a singleton outer packed dimension no
longer subtracts the inner slice width. Permanent coverage includes direct
and associative-owner property events, class-only compound events/waits,
mixed ordinary/VIF-plus-property waits, disable-fork cancellation, resolved
strength sampling, and singleton/ascending/descending packed selects.

Broad native-arm64 validation is clean: legacy 4,072 pass / 2 inherited NI /
3 expected fail / 0 unexpected fail (4,077 total); JSON/VVP 962/962; VPI
100/100; negative diagnostics 123/123; and `make -j1 check` passes. The
real-DPI UVM suite must
be invoked with this worktree's `local-install/bin` first in `PATH`; otherwise
the runner selects Homebrew's stock compiler and reports setup failures.

The commercial fixed-array DPI ABI refinement is also green. The target is
IEEE 1800-2017 Annex H compatibility with VCS, Questa, and Xcelium rather than
a Verilator-specific convention. Open arrays continue to receive an
`svOpenArrayHandle`; sized fixed formals now receive the direct C pointer their
declaration requires. Scalar `bit`/`logic`, explicit packed `[0:0]`, atom,
packed-vector, multidimensional, opposite-direction caller/formal, and
256-/384-bit element cases all round-trip, including X/Z and output/inout
copyback. The fixed-array focus is 12/12 and the full supported REAL-DPI group
is 32/32, both with zero skips. Pure DPI libraries must be
loaded with `vvp -d`; `-m` is deliberately reserved for VPI modules that
provide `vlog_startup_routines`.

The exact OpenTitan SHA-384 import now uses the same commercial ABI: its open
message argument is a handle, while `output int unsigned hash[12]` is a direct
pointer. A fresh compile and bounded replay of the unchanged graph reached
218,117,052 ps and began sequence 5/33 before the 45-second CPU guard. Two
digest predictions and two digest reads completed with zero UVM errors,
fatals, assertions, or crashes. That is a focused ABI proof, not a claim that
the randomized HMAC smoke completed.

The current unchanged HMAC image performs real SHA/FIFO work after the packed
mask correction, and cancellable mixed-wait lowering handles its alert/TL
monitor patterns. The exact rebuilt image reached 3,412,009,286 ps, about 87
times beyond the previous 39,220,884 ps blocker, without UVM errors, fatals,
assertion failures, crashes, or a zero-time stall before the 45-second CPU
guard. This is progress evidence, not a full OpenTitan runtime pass. The
class-only compound `@` subset still has one explicit same-time boundary: a
complete expression that changes and restores before its scheduled waiter
runs can be missed. The frozen Caliptra differential remains
Icarus 53/105 versus Slang 54/105 with zero `ICARUS_GAP`; its full compile,
elaboration, and code-generation path is clean, while a clean application
runtime remains outstanding. The most recent full sv-tests differential is
1,021/1,027 for Icarus (99.4%); its six recorded residuals are separate from
this OpenTitan increment.

Durable technical detail and invocation notes are in
`session_logs/2026-08-25_opentitan_class_events_resolved_preponed_packed_index.md`.

## Resume state — 2026-08-24 — clocking static skew and exact modports

Worktree:
`iverilog-uvm-opentitan-clocking-static-skew-fresh-arm64-20260824`

Baseline: `origin/main` at
`3d9afc7c6094fd382d4f118cfae5cb68b1505329`. The clocking implementation and
initial regressions are `db6b1f7e3` and `2ae389d7a`; the audit follow-up and
its six expanded reducers are committed as `e564c2600`.

The implemented IEEE 1800-2017 boundary is 14.3–14.5 declaration/skew/alias
semantics, 14.13 sampled-input ordering, 14.16 packed output buffering and
scheduling, and 25.5 exact modport visibility. Constant packed member/bit/part
output selects are supported for same-scope, static-instance, alias, and VIF
spellings. Run-time selectors, root or nested indexed class receivers, whole
unpacked output clockvars, and selected declaration-assignment targets without
representable hidden storage are loud boundaries; none may fall through to an
ordinary NBA.

The read-only audit found and drove follow-ups for:

- a root indexed receiver evaluated five times instead of rejected at the
  existing once-capture boundary;
- output-skew elaboration repeated once per static source drive;
- exact modport qualifiers lost through typedef, class type-parameter, and
  unpacked-struct carriers;
- VPI-backed output arguments directly mutating sampled inputs, clocking
  outputs, and modport inputs; and
- a partial nested l-value tree leaked on modport rejection.

The VPI boundary is now precise: integral/string VIF property reads remain
supported, while any `vpi_put_value` to a VIF property is a loud run-time
error, sets a failing status, and leaves the target unchanged. Ordinary
assignments and clocking drives keep their checked language paths.

Post-audit verification is complete: both expanded clocking focuses are
36/36; the SystemVerilog manifest is 1850/1850; JSON/VVP is 918/918; the
default legacy manifest is 4029 pass / 2 NI / 3 EF / 0 fail; VPI is 97/97;
negative diagnostics are 111/111; the clocking Slang differential is 59/59;
`make check` passes; and real-DPI UVM is 338/338.

A fresh OpenTitan replay is 7/7 for setup and compile with zero hard compile
errors. Six long simulations advance through time until the 45-second CPU
guard; ADC retains its known zero-time UVM testbench fatal. No compiler abort
or scheduler assertion occurs. The frozen Caliptra differential remains
Icarus 53/105 in each of assertions, no-assertions, and synthesis versus Slang
54/105, with zero `ICARUS_GAP`; the sole raw Slang lead remains source order.
These are compatibility-frontier results, not clean full-application runtime
pass claims.

Durable detail is in
`session_logs/2026-08-24_opentitan_clocking_static_skew_modports.md`. The local
ignored standards reference is `docs/standards/local/IEEE_1800-2023.pdf`,
SHA-256
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`;
the PDF is not part of the change.

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-28

Branch: `claude/ieee1800-closure-campaign-lqalye`, started fresh from
main and rebased onto `7136907`, which carries the merged PRs #125, #126
and #127. The previous PR on this branch (#121) is merged, so this is a
new pull request rather than a continuation of that one.

### Campaign 2 — whole aggregate value semantics

One missing primitive turned out to explain four separate symptoms. A
fixed unpacked array used where a container is wanted has marshaled its
words since M10-1 (`%load/arr/dar`); the **return trip did not exist**,
and each place it was needed failed differently:

| shape | what it did |
|---|---|
| `fa = da;` and `s.arr = da;` | assigned the **constant 0**, silently |
| `t(fa)` for `inout int q[]` | **aborted ivl** on legal input, even when the body only read the formal |
| `f(fa)` for `ref int q[]` | warned once, then silently left the caller's array alone |

The assignment case is the one worth remembering. `fa = da` is not
`type_compatible`, so it reached the compile-progress fallback in
`elab_and_eval` that substitutes a constant for an incompatible r-value
when the target looks vectorable — and an unpacked array's `cast_type`
is its ELEMENT type, so `int fa[3]` looked exactly that vectorable.

New `%store/arr/dar` is the inverse of `%load/arr/dar`, and all four
paths go through it. The 7.6 element-count rule is checked inside the
instruction, because a dynamic source has no size until it runs; a
mismatch reports and leaves the destination unchanged rather than
half-filling it.

The inbound direction is fixed for **real** elements too: the special
case meant to accept a fixed-array actual for an open-array formal asked
the EXPRESSION for its `netuarray_t`, but a signal expression's
`net_type()` is its element type, so the test never succeeded — integral
arrays slipped past on the vectorable fallback while real arrays took a
cast error.

Roadmap: M10-7 (done), M10-8 (the multidimensional boundary, open and
loud). Tests: `sv_whole_aggregate_value_copy`,
`sv_whole_aggregate_size_mismatch`.

**Verified, not assumed, on the way through:**

- DPI open arrays are complete — re-probed with a fresh C model, not an
  existing test: `svDimensions`/`svSize`/`svLow`/`svHigh`/`svLeft`/
  `svRight`/`svIncrement` all report the **declared** range for
  ascending, descending and non-zero-based actuals, elements read
  through `svGetArrElemPtr1`, and an `inout` formal writes back.
  GitHub issue #45 closed on that evidence.
- Multidimensional open arrays now work at **any legal dimensionality**,
  verified 1-D through 5-D for read, `foreach`, element write and
  whole-array copy-back. That took pushing past **five** separate
  two-dimension caps — see ROADMAP M10-8. The one worth remembering:
  `NetESelect::dup_expr()` dropped the select's `net_type`, so a
  duplicated container select reported no type and `foreach` over a
  three-deep container elaborated two levels and then produced **no loop
  at all** for the third — zero iterations, no diagnostic.

### A finding I had to withdraw

I recorded nested containers — `int d[][]`, `int m[string][]` — as an
unparseable subsystem and filed R19 against it. That was wrong, and the
error was mine: my probe used `foreach (m[k]) foreach (m[k][i])`, which
is not legal SystemVerilog. `foreach` takes one bracket with a
comma-separated variable list. The syntax error was on my `foreach`
line, not on the declaration.

Re-probed with `foreach (m[k,i])`: nested dynamic arrays, queues of
queues and associative arrays of dynamic arrays all declare, allocate
per level, iterate, index, and pass to open-array formals. Nothing there
needed building. R19 is withdrawn; R24 records the withdrawal so the
claim is not rediscovered.

**2026-08-28 correction:** the conclusion in the preceding re-probe was
wrong. A native `int q[][]` formal is a nested dynamic-array formal, not a DPI
open array. Under 7.6/7.7, only its slowest-varying dimension may differ in
array kind; `int[$][$]` has a non-equivalent queue at the faster dimension and
shall be rejected. The positive regression now uses the legal
`int[$][]` queue-of-dynamic-arrays spelling, and a paired compile-error test
pins task/function input, output, and inout rejection of the queue-of-queues
form in both editions.

### Next frontier

Campaign 2's acceptance criteria are all met — see the pull request for
the evidence. The remaining severity-ordered items are R17 (`$typename`
on a parameterized class returns a wrong string — the only *wrong value*
left), then R18, R20, R21, R22, and the deliberately-unvalidated R23.

### Truth pass — 2026-07-28

The five `Phase 7x` GitHub issues were probed item by item rather than
read. #43, #44, #45 and #47 are closed: #45 genuinely complete, the
other three obsolete as tracking units (their acceptance criterion,
"96+/98 regression", names a suite that no longer exists). #46
(performance) is deliberately left open and unre-labelled — its claims
are wall-clock measurements I did not reproduce, and closing it on the
strength of the others would be the sort of unvalidated label this pass
exists to remove.

Sixteen of the twenty-eight probed items were already done. The
survivors carry forward as R17–R23. One correction to my own first
reading: `a.reverse()` returning nothing is **not** a defect — 7.12.2
ordering methods return void, so the r-value spelling I probed with is
not legal SystemVerilog. The in-place form works.

### Gates

`make check`, the vendored ivtest name-diff, bundled VPI, the negative
suite, the SVA dual-run, the DPI subsystem and full UVM — see the pull
request for the run.

One regression was caught by the name-diff and fixed rather than
absorbed: the first cut refused a multidimensional copy-back outright,
which broke `sv_struct_array_member_open_arg` — a member destination had
been working all along through `%store/prop/arr/dar`. The new path now
takes over **only** a plain word-array signal destination, which is the
one shape that had no instruction.
