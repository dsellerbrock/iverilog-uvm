# Virtual-interface, dynamic event-list, and left-`$` queue-slice refinement (2026-08-30)

Worktree
`iverilog-uvm-opentitan-syntax-event-frontiers-after245-arm64-20260828`, branch
`agent/opentitan-syntax-event-frontiers-after245-arm64-20260828`, based on
`affd74d41` (the PR 245 merge). Nine pushed implementation/test commits run
from `b5692b918` through `00e3d74dd`; this documentation and test-classification
checkpoint follows them. Native Apple Silicon ARM64 tools were used
throughout. The compiler was generated with Homebrew Bison 3.8.2 and Apple's
`/usr/bin/flex`, then compiler and simulator invocations ran through the shared
45-second CPU guard without an RSS ceiling.

This branch joins three bounded language mechanisms because they met in the
same parser/elaboration frontier. It does not treat them as one conformance
claim.

## Normative audit

IEEE 1800-2017 and IEEE 1800-2023 have the same relevant rules for this
increment:

- 25.9 and Syntax 25-3 define `virtual [interface]
  interface_identifier [parameter_value_assignment] [. modport_identifier]`,
  its legal declaration use, its port/interface-item/union exclusions, and
  comparison with null, an equivalent virtual interface, or a matching
  concrete interface instance using `==` and `!=`.
- 23.6 requires a select of an instance array in a hierarchical name to be a
  constant expression. The separately tested run-time-variable select from an
  unqualified one-dimensional interface-instance array is therefore an
  intentional application-compatibility extension, not 25.9 conformance.
- 9.4.2 permits an event expression or an `or`/comma-separated event list. The
  list must preserve the individual semantics of ordinary expressions, 6.17
  event variables and arrays, 14.10/14.12/14.14 clocking events, and the named
  or class events covered by 15.5.
- 7.10.1 permits queue range expressions with integral bounds and gives `$`
  the live queue's last index. This increment covers `$` as the left endpoint
  of an r-value range.

Slang 11 accepts the core 25.9 positive in both edition modes and rejects the
run-time-variable instance-array select required by the compatibility
extension. It also accepts VIF `===`/`!==` and `==?`/`!=?`, despite 25.9
listing only `==`/`!=`. That disagreement is recorded rather than used to
weaken the normative Icarus diagnostics. No VCS, Questa, or Xcelium executable
was used as an oracle for this increment.

## 25.9 declaration provenance and contexts

The parser now routes `virtual iface` and `virtual interface iface` through a
shared type production for known, forward, parameter-spelled, and
modport-qualified interface names. `interface_type_t::virtual_type` retains
the source fact that this was a virtual-interface data type instead of asking
the shared elaborated interface netclass to reconstruct it later.

The recursive provenance query follows unpacked-array carriers, forward and
package-qualified typedefs, concrete type-parameter defaults and actuals, and
`type(expression)` with lexical lookup. That makes the context check stable at
the declaration boundary:

- compilation-unit, package, module, block, declaring-for, unpacked-struct,
  qualified class-property, and task/function/method argument and return uses
  remain legal;
- module, interface, and program ports, interface items (including indirect
  typedef/type-parameter and generate carriers), and union members are
  rejected; and
- ordinary interface ports are not mistaken for forbidden VIF ports merely
  because both ultimately use an interface netclass.

Removing redundant protected-virtual method-only grammar shortcuts leaves the
shared class-item dispatch responsible for those declarations. The final
Homebrew Bison report is 533 shift/reduce and 1119 reduce/reduce conflicts,
against 535/1119 at the merge base. Canonicalized conflicting-state item cores
show no unintended terminal-action change; the two removed shifts belong to
those redundant shortcuts.

## 25.9 comparison identity and lowering

Comparison classification runs before generic object or integral lowering.
Only `==` and `!=` admit the evidenced unparameterized VIF cases: null, an
equivalent VIF, or a same-definition concrete interface instance in either
operand order. The ordinary expression and `test_width` paths use the same
non-evaluating lexical preflight and exact owner-scope collection, so width
probing cannot evaluate an operand, emit a duplicate diagnostic, or bind an
outer interface-instance array through a block-local scalar-array shadow.

The lowering retains constant one-dimensional instance-array elements,
same-type conditional VIF results, rebinding, and null. At run time,
`%cmp/obj` recognizes the case where both operands are VIF wrappers and
compares their bound scopes plus interface definitions. Two separately
allocated wrappers for one interface instance therefore compare equal and
different instances do not. The generic pointer comparison remains unchanged
for ordinary class objects, and null handling remains non-dereferencing.

The positive test also pins an instance whose identifier has the same spelling
as its interface type. Exact negatives cover a scalar operand, different
interface definitions, two direct concrete instances, case equality and
inequality, wildcard equality and inequality, and lexical shadowing. The
run-time-variable interface-instance-array cases live in the separately named
`sv_vif_instance_runtime_index_extension{,_2023}` test so the compatibility
extension cannot be counted as normative 25.9 evidence.

## 9.4.2 dynamic event-list leaves

Previously, splitting a mixed event list around a class-property or VIF-member
leaf could discard the special lowering for a named event, selected event-array
element, or clocking event. A rejected prospective leaf could also elaborate
twice, duplicating side effects and diagnostics.

Each prospective leaf is now prepared exactly once. Its retained netlist
expression and leaf classification are transferred into exactly one lowering
path. A dynamically selected VIF-member or class-property leaf can be listed
with ordinary signals, named events, a run-time-selected event-array element,
and direct, default, or global clocking events without converting those leaves
to generic value-change expressions.

The dynamic waiter families run as independently cancellable one-shot helpers
under an isolated join-any selector. The first winner resumes the user
statement once and unlinks every loser. Simultaneous source changes still
resume once, same-value or masked class-property writes do not wake, and
cleanup does not cancel an unrelated child previously detached by the user's
`join_none`.

This does not broaden a single event-expression leaf whose expression itself
mixes VIF and class/ordinary dependency families. That form remains a focused
error. The earlier class-compound snapshot limitation and root/handle,
associative-key, and run-time-index mutation boundaries while armed are also
unchanged.

## 7.10.1 `q[$:hi]` r-values

The range carrier now records `$` as the left queue endpoint instead of routing
it through packed-select parsing. Lowering evaluates the receiver once, then
emits the dedicated `%qslice/left/f` form. VVP derives `$` from that already-
evaluated queue's live last index and evaluates the explicit integral `hi`
once.

An exact or above-last `hi` returns the final element after normal queue-range
clamping. A lower/reversed or X/Z `hi`, or an empty source queue, returns an
empty queue. The result is always an unbounded queue, including when the source
is bounded. Direct signals, selected and static class properties, methods,
unevaluated type queries, integral, logic, real, string, class-handle, and
nested-container elements are pinned. Nested container values receive a fresh
copy; class handles retain their object identity.

A nonqueue receiver and a nonintegral explicit bound are errors. Assignment to
`q[$:hi]` remains a focused loud `sorry`, and `$` as the base of an indexed
`+:`/`-:` range is separate work.

## Permanent evidence

| Area | Registered evidence |
|---|---|
| VIF spelling and legal contexts | `sv_vif_explicit_interface_class_property{,_2023}`, `sv_vif_explicit_interface_data_type_contexts{,_2023}` |
| VIF forbidden contexts and bad type names | `sv_vif_forbidden_{port,interface_item,interface_item_type_parameter,union_member}_fail{,_2023}` and `sv_vif_explicit_interface_class_{missing,modport,noninterface}_fail{,_2023}` |
| Normative VIF equality | `sv_vif_instance_comparison{,_2023}` plus six sources under `tests/negative/vif_comparison_*` |
| §23.6 compatibility extension | `sv_vif_instance_runtime_index_extension{,_2023}` |
| Dynamic event lists | `sv_class_property_mixed_event_value_change`, `sv_event_list_vif_{mixed_once,preserved_leaves}{,_2023}`, and the prepare-once diagnostic pairs |
| Left-`$` queue slice | `sv_queue_slice_dollar_left{,_2023}`, `sv_queue_slice_dollar_left_fail{,_2023}`, and `sv_queue_slice_dollar_left_lvalue_fail{,_2023}` |

## Validation

All results use the worktree-local native ARM64 install.

| Suite | Result |
|---|---:|
| VIF context/comparison/extension focus, legacy | 22/22 |
| VIF context/comparison/extension focus, JSON/VVP | 22/22 |
| Chapter-9 statement/event focus, legacy | 14/14 |
| Chapter-9 statement/event focus, JSON/VVP | 14/14 |
| New left-`$` queue rows, legacy | 6/6 |
| New left-`$` queue rows, JSON/VVP | 6/6 |
| Full legacy | 2,188/2,188 |
| Full JSON/VVP | 1,266 ran, 0 failed (1,249 pass, 17 unchanged NI) |
| Negative diagnostics | 149/149 |
| VPI | 103/103 |
| Canonical real-DPI UVM | 354/354 |

No OpenTitan or Caliptra application matrix was replayed for this branch. The
results above do not change either application's pass/fail counts or source
frontier.

## Exact remaining boundaries

- Parameter specialization and modport selection are not complete parts of
  VIF comparison type identity. A parameterized VIF declaration still warns
  that default member widths are used, so nondefault member-width semantics
  are not claimed.
- The run-time-variable instance-array select is the explicit 23.6 extension
  described above. Only the unqualified one-dimensional bit-select dispatch is
  evidenced; hierarchical and multidimensional run-time dispatch are not.
- A single event-expression leaf combining VIF and class/ordinary dependencies
  is still rejected. Existing compound-snapshot and armed-owner/key/index
  mutation limits remain.
- `q[$:hi]` is r-value-only. Its l-value form and `$` as an indexed-range base
  remain loud.

These limits keep this checkpoint bounded. It is not complete clauses 7, 9,
23, or 25 support and is not an OpenTitan or Caliptra application result.
