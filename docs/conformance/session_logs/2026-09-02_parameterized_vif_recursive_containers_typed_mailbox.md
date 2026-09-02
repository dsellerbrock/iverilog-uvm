# Parameterized virtual interfaces, recursive containers, and typed mailboxes (2026-09-02)

## Scope and status

This increment joins three related type-preservation paths without claiming
complete clauses or application closure:

- parameterized-interface and modport identity through physical interface
  ports and dynamically rebound virtual-interface method calls;
- recursive queue, dynamic-array, and associative-array (Q/D/A) layout and
  value provenance, including those container types as fixed unpacked-array
  elements; and
- typed-mailbox equivalence checking plus a real l-value carrier for the
  `get`, `peek`, `try_get`, and `try_peek` message argument.

The working tree is
`iverilog-uvm-param-vif-specialization-after250-arm64-20260901` on branch
`agent/param-vif-specialization-after250-arm64-20260901`, based exactly on
`origin/main` `dcd3f8fc1e293ffd4ecd4c559273be5f904fe5e4`.

The measured evidence in this log is intentionally focused. The final broad
compiler/UVM sweep and the unmodified OpenTitan and Caliptra replays have not
yet run for this increment. Mailbox source integration is still awaiting its
final installed-tool reducer run, so it has no passing count here.

## Normative audit

The local, untracked IEEE 1800-2017 and IEEE 1800-2023 LRMs were read directly.
The implemented rules used by this increment are shared by both editions,
with one clause-numbering note for multidimensional arrays:

| Area | IEEE 1800-2017 | IEEE 1800-2023 | Rule applied |
|---|---|---|---|
| Type identity | 6.22.1, 6.22.2 | 6.22.1, 6.22.2 | Matching and equivalence are distinct relations. Packed types can be equivalent without matching; nominal class, enum, and unpacked aggregate identity remains declaration-sensitive. |
| Fixed and nested arrays | 7.4.2, 7.4.5 | 7.4.2, 7.4.4 | An unpacked array may have any data type as its element, including another packed or unpacked array. The 2023 edition renumbers the multidimensional-array subclause but retains the rule used here. |
| Variable-size containers | 7.5, 7.6, 7.8, 7.10 | 7.5, 7.6, 7.8, 7.10 | Dynamic arrays, associative arrays, and queues retain their own kind, element type, ordering, bounds, and assignment behavior when nested. |
| Subroutine actuals | 13.5 | 13.5 | Output and inout actuals shall be valid procedural l-values and copy back on return; a `ref` actual shares the selected variable representation. |
| Mailbox outputs | 15.4.5-15.4.8 | 15.4.5-15.4.8 | Retrieval methods take one valid left-hand expression. Blocking methods capture that actual when called; an unsuccessful try method performs no message copy. |
| Typed mailboxes | 15.4.9 with 6.22.2 | 15.4.9 with 6.22.2 | Every typed-mailbox message method uses a type equivalent to the mailbox type. This is equivalence, not merely assignment compatibility and not the stricter matching relation. |
| Modport methods | 25.7 with 6.22.1 | 25.7 with 6.22.1 | A full import/export prototype shall match the interface subroutine declaration. Equivalent-but-nonmatching packed representations do not satisfy this rule. |
| Interface and VIF type | 25.5, 25.9 | 25.5, 25.9 | Actual parameter values/types and the selected modport participate in interface/VIF type; a VIF call selects the currently bound physical instance. |

There is no implemented `-g2023`-only semantic path in this cluster. Paired
tests exercise the shared behavior under both selected editions.

## Parameterized-interface and modport dispatch

The prior lowering could preserve a generic interface declaration yet lose
which parameter specialization and physical instance supplied a method. That
was particularly visible when an interface-local enum, unpacked record, or
class result was elaborated into separate netlist objects for the declaration
view and for each concrete interface instance.

The current design retains two kinds of identity deliberately:

1. The semantic VIF/interface type contains the evaluated parameter
   specialization and selected modport, as required by 25.9.
2. Each physical interface scope retains its own carrier for declarations
   whose identity is local to that instance. Dynamic dispatch maps only the
   corresponding parsed declaration and compatible specialization; it does
   not accept an unrelated specialization merely because a layout happens to
   be similar.

A call records the compatible physical candidates rather than selecting an
arbitrary instance during elaboration. At run time the bound VIF selects the
candidate. Scalar task `output`, `inout`, and `ref` rows are also selected from
that candidate, so rebinding changes both the executed body and its writeback
target. Function results preserve the interface-local nominal correspondence
for the evidenced enum, unpacked-record, and class forms.

Modport declarations are checked using the 6.22.1 matching relation. Identifier
imports reuse the interface declaration signature for ordinary positional
calls; full prototypes are required for the cases named by 25.7 and are
validated even when never called. Visibility, missing export implementations,
argument directions, formal names when significant, fixed bounds, array kind,
associative index type, packed shape, defaults, and duplicate declarations are
kept as focused diagnostic boundaries.

Parser recovery is part of the same work. A malformed prototype now clears
the pending modport item, and an unterminated prototype at the end of one
physical source file cannot contaminate the next file's legal interface and
modport declarations. The exact diagnostic golds contain only the malformed
source's intended errors.

## Recursive Q/D/A layout and fixed container elements

The VVP object carrier now records the complete recursive Q/D/A declaration
layout instead of only the outer container kind. A layout node identifies the
container kind, a queue's full bound state, and the child container layout.
Construction, copying, assignment, method receivers, and nested element
insertion reapply the destination's declared layout recursively.

This is needed for observable language behavior. A bounded queue nested below
a dynamic or associative array must still truncate according to its own bound;
a value copy must be independent; and storing an incoming container into a
named signal must update the new copy's root provenance rather than later
writing an obsolete pre-copy object back to the signal. Queue ordering and
randomization-related mutation paths use the actual object receiver so their
updates reach the selected property or container root instead of a private
temporary.

The frontend now admits a fixed unpacked-array word whose element is a queue,
dynamic array, associative array, or a recorded recursive Q/D/A composition.
Selecting the fixed word leaves that word as the method or nested-index
receiver, evaluates its index once, and retains the inner container's bound
and rank. This is the 7.4 array-of-arrays rule, not a scalarization shortcut.

New VVP images carry a strict recursive layout suffix. Legacy images remain
accepted on their legacy path, while malformed or overflowing new metadata is
rejected before scheduling. This log does not promote the bounded carrier to
general recursive aggregate or bit-stream-cast closure.

## Typed mailbox equivalence and reference outputs

Typed-mailbox specialization and method checking now share one semantic
equivalence query. The intended result is:

- a class and its typedef alias are accepted;
- nominally distinct classes are rejected;
- distinct packed-structure declarations are accepted when 6.22.2 makes them
  equivalent, even though 6.22.1 does not make them matching; and
- the bare `mailbox` and explicit `mailbox#()` dynamic forms remain typeless.

For retrieval, the netlist statement/function nodes can own a real elaborated
l-value rather than only an r-value expression. The target API exports that
l-value and VVP captures its receiver, root, selector, and index before the
mailbox operation can block. The intended writeback path covers direct scalar,
string, real and class-handle variables, packed bit/part selects, class
properties, fixed-array words, and queue/dynamic-array elements. A successful
try operation writes the captured target; an empty try leaves it unchanged.

This mailbox section is an implementation checkpoint, not a verified support
claim. The final installed-tool positive/negative reducers are still pending,
and associative-array-element reference lifetime remains under integration.
The permanent sources prepared for that gate are:

- `sv_typed_mailbox_type_identity`;
- `sv_typed_mailbox_statement_type` and
  `sv_typed_mailbox_statement_type_fail`;
- `sv_typed_mailbox_expression_type_fail`;
- `sv_mailbox_ref_output_lvalue` and `sv_mailbox_ref_output_fail`; and
- the corrected empty-try expectation in `sv_mailbox_try_int1`.

Every new source has a paired 2017/2023 registration where the feature is
edition-selected.

## Focused evidence at this checkpoint

| Gate | Result | Meaning |
|---|---:|---|
| New VIF nominal-result and task-copyback rows, legacy | **8/8** | Four positive/negative basenames, each paired for 2017 and 2023. |
| New VIF nominal-result and task-copyback rows, JSON/VVP | **8/8** | The same paired behavioral and diagnostic surface passes the split-stream harness. |
| Exact-main compiler on those rows, legacy | **0/8** | The separately built exact-base tool fails every row, providing a red proof for the new behavior. |
| Exact-main compiler on those rows, JSON/VVP | **0/8** | The separately built exact-base tool also fails every split-stream row. |
| Repaired recursive-container regression cluster | **13/13** | The shared provenance/layout repair closes the isolated pre-existing regression set on this branch. |
| Interface-port-array cluster | **4/4** | Member access, selected task copyback, and the parameterized/forwarded array paths pass together. |
| Fixed-array-of-container edition pair | **2/2** | `sv_fixed_container_array_elements` passes in 2017 and 2023 modes. |
| Modport parser recovery | **verified** | In-item, syntax-error, and two-file EOF recovery retain their exact diagnostics without contaminating a following declaration. |
| Typed mailbox final reducer gate | **pending** | No passing count is claimed until the coherent compiler/runtime is installed and the complete focused list runs. |

The 13-row container set includes queue autovivification, signed associative
traversal, associative defaults/function output, parameterized-class identity,
struct and explicit-pattern value copies, container `randc`/`rand_mode`, and
positional associative-element type cases. The four-row interface array set
includes `sv_interface_port_array_member`,
`sv_interface_port_array_copyback_task`,
`synth_parameterized_interface_member_array`, and
`synth_forwarded_parameterized_interface_array`.

## Application and broad-regression boundary

No full legacy, JSON/VVP, negative, VPI, DPI/UVM, OpenTitan, or Caliptra replay
is attributed to this increment yet. Until those runs complete, the last
recorded application baselines remain unchanged:

- OpenTitan: **192 PASS of 530 classified rows**, with 20 `DEBT`, 104 `FAIL`,
  16 `RUNTIME_FAIL`, 157 `DEPENDENCY_ONLY`, 35 `UPSTREAM_INVALID`, and 6
  `SETUP_FAIL`. No clean OpenTitan UVM compile or runtime pass is implied.
- Caliptra/Adams Bridge static census: Icarus **53/105** in each assertions,
  no-assertions, and synthesis lane versus Slang **54/105**, classified as 52
  `PASS`, 1 `DEBT`, 51 `SHARED_SOURCE_OR_CONFIG`, and 1 `SOURCE_ORDER_DEBT`.
  This remains a static RTL/SVA/synthesis census, not complete Caliptra DV/UVM.

The next evidence boundary is a coherent native-ARM64 build/install, the full
focused list including mailbox reference outputs, the broad compiler/UVM
gates, and then fresh unmodified OpenTitan and Caliptra application replays.
Only those replays can change the recorded application totals.

## Honest boundary

This increment does not claim complete IEEE 1800 clauses 6, 7, 13, 15, or 25;
complete parameterized/modport VIF behavior; arbitrary recursive aggregate
semantics; full mailbox reference lifetime; full UVM compatibility; or a clean
OpenTitan/Caliptra application flow. It closes measured mechanisms and leaves
the remaining validation and unsupported shapes visible.

## Addendum — 2026-09-02 — multi-index container method receiver

Running the pending focused gate turned up one red row,
`sv_vif_parameter_specialization_queue_bound_layout`, in both editions. The
reported symptom was misleading and the investigation is recorded here because
the conclusion changed twice.

The row's own message said the Q<D<Q>> copy had not recursively enforced the
destination bound. That is not what happened. Routing the same read through a
temporary returns the correct sizes:

    ta = a[0][0]; tb = b[0][0];   ->  ta.size() = 3, tb.size() = 5

so the recursive bound enforcement implemented by this increment is correct.
The assertion failed because it reads `deep_qdq_2[0][0].size()` directly, and
that read returned the wrong object.

### Defect

IEEE 1800-2017 7.4, 7.8, 7.10, 7.12. A built-in container method whose
receiver carries two or more index components was dispatched against the
**bare root signal**; every index component was dropped and no diagnostic was
emitted. With an outer queue of 2, a darray of 3 and an inner queue of 4:

    b.size()        = 2
    b[0].size()     = 3
    b[0][0].size()  = 2      <- returned b.size(); wants 4

Two sites, both in `elab_expr.cc`:

- `PECallFunction::elaborate_expr_method_`: the root-container-index branch was
  guarded on `path_head.back().index.size()==1`, and the branch above it only
  matched a trailing unpacked-array slice. A two-or-more index receiver matched
  neither, so no select was built at all.
- `PECallFunction::test_width_method_`: the companion type analysis stepped
  `darray->element_type()` exactly once regardless of the index count, leaving
  the method typed a container level too shallow. This is why
  `qdq[0][0].pop_front()` failed elaboration as an unpacked aggregate assigned
  to a scalar target rather than yielding `int`.

### Provenance

Pre-existing on `origin/main` at `dcd3f8fc1`, not introduced by this increment.
The exact-main compiler built in the `iverilog-uvm-svtests-qualified-if-20260813`
worktree reproduces the reducer identically. The depth-three test added by this
increment merely made a latent defect reachable, so it is fixed as its own
commit with its own regression.

### Implementation

The expression site now routes any receiver with more than one index component
through `apply_trailing_container_indices_()`, the walker the trailing-slice
case already used. It consumes every component and reports a focused diagnostic
for a chain it cannot represent, so no index is dropped silently: the
previously silent `b[0 +: 2][0].size()` now reports
"sorry: this container slice/index chain is not yet supported."
The width site consumes every component for all-bit-select receivers, mirroring
the associative walk directly above it; slice-bearing receivers keep their
established typing so the fix cannot disturb them.

A second, separate silent degradation was found while reconciling the row's
gold. `vvp_queue::apply_declared_container_layout_own()` discards elements when
it applies a declared bound, but did so without the
"queue<...> is bounded to have at most N elements" warning that the counted
copy path emits. A whole-queue copy of a 5-element source into a bound-3
destination truncated correctly but silently. The trim now reports through a
new `queue_element_type_name()` hook on the queue subclasses.

The three gold files for `sv_vif_parameter_specialization_queue_bound_layout`
were authored earlier in this increment and had never been validated against a
built tool. They are regenerated here, and every line was traced to an
intentional action in the source: the bound-enforcement warnings, the
indexed-store refusal at line 115, the four recursive-trim warnings from the
A-to-Q, D-to-Q, Q<D<Q>> and Q<A<Q>> copies, and the two
`container index 4294967296 exceeds the runtime index range` diagnostics from
the deliberate `wide_index = 64'h1_0000_0000` selector rejection.

### Regression

`sv_container_method_multi_index_receiver`, paired for `-g2017`/`-g2023` in
`regress-sv.list`, `regress-vvp.list` and `ivtest/vvp_tests/`. Each nesting
level carries a distinct population so any wrong receiver is observable rather
than aliasing a correct answer. It is red on the exact-main compiler and green
here.

### Known limitation, not addressed here

The statement/task path keeps its existing single-index restriction:
`b[0][0].push_back(9)` reports
"sorry: Only single-dimension index of dynamic/queue method targets is
supported." (`elaborate.cc:1535`, `elaborate_root_indexed_method_target_expr_`).
That path is loud rather than silent, so it is a visible gap and not a
correctness defect. Closing it needs the container walker, currently a static
in `elab_expr.cc`, to be shared with `elaborate.cc`; that is deliberately left
out of this commit rather than widened into it.

## Addendum 2 — 2026-09-02 — nested constructor aliased its caller's object

The first full `vvp_reg.pl` sweep of this increment did not finish: it stopped
on `sv_class_assoc_recursive_find1`, which spun in `vvp` producing no output at
all. `origin/main` at `dcd3f8fc1` runs the same row to `PASSED` in under a
second, so this was a regression introduced by this increment and not by the
multi-index receiver fix recorded above. That was established by reverting
files individually and rebuilding each time: reverting `elab_expr.cc` alone
still hung, and reverting `vvp/vvp_darray.{cc,h}` as well — the pure checkpoint
`cab3515d6` — still hung.

Note for future sweeps: run them as `ulimit -t 45 && perl vvp_reg.pl`.
`vvp_reg.pl` does not itself apply the campaign's per-process CPU guard, so a
single spinning row stalls the entire run and no summary is ever printed.

### Defect

IEEE 1800-2017 8.7, 8.10. `of_STORE_OBJ` read the destination signal's
post-store value back with `fun->peek_object()` in order to detect the private
handle that a Q/D/A signal substitutes when it receives a container by copy.
For an automatic signal `peek_object()` resolves through the thread's READ
context, while the store immediately above it goes through the thread's WRITE
context. Inside a constructor invoked from another constructor of the same
class those are different frames:

    scope=$unit::C.new fun=object_aa wt=0x105d47e30 rd=0x105d49fa0

so the read-back returned the CALLER's `this` and the destination's alias
provenance was redirected at the caller's object. A nested `new` therefore
aliased its own parent and the inner constructor's property writes landed on
the outer object:

    root = new("common", 0);        // root.child === root
    root.nm    = "common"   d = 1   // outer depth overwritten by the child
    child.nm   = "common"   d = 1   // inner name never reached its own object

The formals themselves were always passed correctly — tracing the constructor
shows `name=common_end depth=1` on entry to the nested call — which is why this
presented as corrupted properties rather than as a call-argument fault.

The non-termination follows from the same aliasing. A constructor whose
recursion is bounded by an argument, which is the ordinary UVM phase-graph
shape, builds its terminal child with a different type and a non-null parent.
With the child observing the parent's arguments the stopping guard never became
false, so `sv_class_assoc_recursive_find1` recursed without end.

### Implementation

The read-back is now taken only when the stored value is actually received by
copy, that is when it is a container. A class handle is stored as-is and keeps
the unambiguous stored value as its provenance. This preserves the Q/D/A copy
fix the read-back was added for and removes the cross-context read for the case
where it was never meaningful.

The container test must name two types. Queues and dynamic arrays are
`vvp_darray`, but an associative array is `vvp_assoc_base`, which is a SIBLING
of `vvp_darray` and not a subclass. A first version of this fix tested only
`vvp_darray` and so dropped associative arrays out of the copy path; the full
sweep caught it immediately as six newly red rows -- `sv_assoc_default_values`,
`sv_assoc_default_struct_value_copy`, `sv_assoc_explicit_pattern_values`,
`sv_assoc_function_output`, `sv_assoc_signed_traversal` and their 2023 pairs.
This is precisely why the acceptance criterion is a diff of failure NAME SETS
against a freshly built main and not a pass count: the count moved 16 -> 18,
which looks like noise, while the set showed four rows repaired and six
distinct rows broken.

### Regression

`sv_class_nested_ctor_provenance`, paired for `-g2017`/`-g2023`. It asserts the
nested `new` produced a distinct object, that the outer frame's name, depth and
parent all survive the inner invocation, that the inner actuals reach the inner
object, and that the bounded recursion terminated with no grandchild. It also
covers the four rows this defect was breaking:
`sv_class_assoc_recursive_find1`, `sv_class_recursive_new_prop1`,
`sv_class_derived_ctor_state1` and `sv_class_recursive_ctor_add1`.

## Addendum 3 — 2026-09-02 — mailbox ref-output into a class property

Closing out the rows the full sweep still showed red.

### Defect

IEEE 1800-2017/2023 15.4.5-15.4.8. A mailbox `get`/`peek`/`try_get`/`try_peek`
target that names storage inside an object, reached DIRECTLY through a handle
signal rather than through a nested l-value, took the plain-signal path in
`draw_capture_lval_ref` (tgt-vvp/stmt_assign.c) and captured the class HANDLE
instead of the property. The property path immediately below it already
implemented every shape needed -- scalar, container element and associative
element -- but was gated on `ivl_lval_nest(lval)`, which a direct
`handle.property` spelling does not set.

Two failure modes, one cause:

- `mi.get(h.values[0])` and `mi.get(h.int_map[5])` reported
  "sorry: unsupported indexed mailbox ref-output signal shape";
- `mi.get(h.value)` compiled CLEAN and then aborted vvp at run time with
  "internal error: 24vvp_fun_signal_object_sa: recv_vec4 not implemented",
  an internal assertion reached from an accepted program.

The second is the more serious of the two: an accepted program must not reach
an internal assertion, and nothing in the compile output warned about it.

### Implementation

A property target names storage inside the object, not the handle signal, so
it now belongs to the property path whichever way the owner is spelled. The
signal path is guarded with `property < 0` and the property path's gate drops
`ivl_lval_nest`; `draw_lval_expr()` already pushes the owning object for a
direct-signal l-value as well as a nested one, so both spellings share the
existing emission.

### Test correction, not a compiler change

`sv_mailbox_ref_output_lvalue` then reached its `packed part RMW` check and
failed it. The compiler is right and the test was wrong: the check ran after
the preceding `packed bit RMW` had already left `packed_value` at `16'ha558`,
so replacing `[11:8]` with `3` yields `16'ha358`, not the `16'ha35a` the test
asserted -- that value ignores the earlier read-modify-write. Measured against
the exact-main compiler, which implements neither RMW and leaves `16'ha55a`
untouched, this branch produces `a558` then `a358`, both correct. Only the
expectation was corrected.

### Regression

`sv_mailbox_ref_output_class_property`, paired for `-g2017`/`-g2023`. It covers
the unindexed property (the former assertion abort), the queue-element and
associative-element properties (the former `sorry`), a signal-backed queue
element as a control for the path that already worked, a successful `try_get`
through a property, and an empty `try_get` leaving the property untouched. On
the exact-main compiler four of its checks are red.

### Known limitation, unchanged

`mi.get(assoc[key])` on a SIGNAL-backed associative array still fails to create
or write the element -- `plain_map[3]` stays 0 and `size()` stays 0. That is
pre-existing on `origin/main` at `dcd3f8fc1` and is a separate defect from the
property path fixed here; it is not addressed in this increment.
