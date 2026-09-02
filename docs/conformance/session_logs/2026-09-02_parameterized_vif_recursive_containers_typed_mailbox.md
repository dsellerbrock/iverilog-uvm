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
