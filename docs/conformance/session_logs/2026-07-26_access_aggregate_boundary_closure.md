# 2026-07-26 — access and aggregate boundary closure

## Starting point

The campaign began at the merge of PR #121 (`9ca10bd18`). The latest main
CI run was green. A pristine build of that commit reproduced all three
target defects:

- `repros/struct_array_member_access_matrix.sv` passed an integral fixed
  struct member to an open formal and silently computed 0 instead of 806;
- `$cast` into a local/nested container element aborted VVP or returned
  without updating the selected destination;
- `foreach (u[4].inner.bus[i])` ran without touching the selected instance.

## M4B-15 — whole fixed struct members at open-array boundaries

A fixed unpacked-array member of an unpacked struct is stored as inline
property words. The old object evaluator treated the whole member as an
object slot, so an open-array formal received an empty value.

The target now recognizes a whole fixed-array property and emits a
materialization operation. Class/struct property metadata retains every
declared range, and the runtime builds a typed nested darray from the inline
words. It supports integral atoms, vectors, real, string/object storage
where represented, and multidimensional rectangular members.

The declared ranges are deliberately passive on the materialized value.
Ordinary assignment from a fixed member to a dynamic array therefore keeps
normal dynamic-array indexing (`0..size-1`). Installing that value in an
open-array formal activates the declared-index view recursively. Runtime
array queries, `foreach`, element loads/stores, and DPI H.10 accessors then
translate the fixed actual's indices consistently.

Output and inout copyback use a matching aggregate-property store. The
receiver abstraction handles class objects and virtual interfaces, so the
same materialization/copyback works for a direct struct, a struct in a
class property, a struct reached through a runtime container, and direct or
virtual interface members in ordinary SV calls.

Permanent coverage:

- `ivtest/ivltests/sv_struct_array_member_open_arg.v`: SV input/output/inout,
  ascending/descending and nonzero ranges, byte/shortint/int/real,
  multidimensional shape and copyback, direct/class/container/interface
  receivers, runtime `foreach` and array-query functions, plus the ordinary
  zero-based dynamic-array control;
- `tests/m4b_struct_array_member_open_test.{sv,c}`: the same semantic
  boundary through real DPI, including `svDimensions`, size/bounds/
  increment, `svSizeOfArray`, multidimensional element pointers, and
  output/inout copyback.

The final multidimensional SV copyback exposed one asymmetric runtime path:
`%load/qo` translated declared indices but `%store/qo` did not. The store
now applies the same canonical translation.

## M1C-7 / R16 — `$cast` destinations and indexed hierarchy `foreach`

Class downcasts already had a runtime type check, but the destination
lowering accepted only scalar signals and direct properties. SELECT
destinations now dispatch through the normal assignment stores:

- fixed unpacked-array element;
- dynamic-array element;
- queue element;
- associative-array element;
- nested queue/associative receiver.

Both constant and variable indices are covered. A successful downcast
updates the selected element. A failed function-form cast returns 0 and
leaves the element unchanged; task form emits the clause-6.24.2 diagnostic
and also preserves it.

The `foreach` grammar previously discarded a hierarchical prefix select.
It now retains that select as part of the hierarchy and keeps the loop
indices on the final array target. Elaboration accepts indices on prefix
components, while a real local runtime array takes precedence over a
same-named class property when choosing the loop-index type.

Permanent coverage:

- `sv_cast_container_destination`;
- `sv_cast_container_task_failure`;
- `sv_foreach_indexed_instance_target`.

The `foreach` test covers a one-dimensional instance array, nested hierarchy
after the selected component, one- and multidimensional target arrays,
reads and writes, and local/unindexed/class-shadow controls. Direct
multidimensional arrays of instances remain loudly unsupported because the
compiler does not represent that declaration shape.

## Access-family audit and final gates

The existing class-property container, nested-container, interface/
virtual-interface, and hierarchical `foreach` regressions pass alongside
the new tests. The pristine PR-121 build fails each new regression for its
claimed reason.

Final results:

- `make check`: pass;
- negative suite: 61/61;
- SVA legacy/NFA dual-run: 36/36;
- ivtest name-diff: 3,217 total, exactly 44 expected failures, no drift;
- VPI: 92/92;
- full UVM, real DPI: 226/226 with no skips;
- installed and relocated `-uvm` frontend: all eight scenarios pass.
