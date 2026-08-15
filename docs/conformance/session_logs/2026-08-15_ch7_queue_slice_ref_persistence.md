# 2026-08-15 — Chapter 7 queue slices and element-reference lifetime

## Starting evidence

The pinned full `sv-tests` replay classified two Chapter 7 positives as
`ICARUS_REJECT_SLANG_ACCEPT_POSITIVE` or run-time semantic failures:

- `chapter-7/queues/pop_back_assing.sv` was rejected at `q[0:$-1]`;
- `chapter-7/queues/persistence.sv` lost the value of a queue element that
  had been passed by `ref` and then removed.

Slang `11.0.415+8acc660a2` accepts both sources. IEEE 1800-2017 7.10.1
defines `$` as the last queue index, while 7.10.3 and 13.5.2 require a
reference to an array or queue element to remain attached to that element
through index changes and to keep an outdated private value after removal.

## Queue slice endpoint

The parser now preserves `$-expression` as the right endpoint of a queue
slice in both scoped-expression and hierarchy-identifier paths. Expression
lowering emits dedicated `slice_last` and `slice_offset` operations, which
derive the last index from the already evaluated receiver and therefore do
not duplicate a side-effecting class-property receiver. Assignment to
`[lo:$-offset]` is parsed but rejected with an exact `sorry` until the
queue-slice l-value ABI can carry both run-time bounds; ordinary `[lo:$]`
l-values retain their existing support. Existing `$-expression` element
selection, ordinary part selection, and indexed part-select paths are
unchanged. Bison remains at 535 shift/reduce
and 1115 reduce/reduce conflicts; the normalized 201-state conflict profile
matches the clean baseline (`7cac47ae8107f44703821dc4d25d3b2f7b3c2a9ec39ac4dc61f94d6d39fe4395`).

## Stable element cells

An element bound to a task `ref` formal now has a reference-counted stable
cell. While the element is present, the cell reads and writes its live
container storage. Queue insertion, deletion, pop, bounded-tail removal, and
ordering operations move the cell with the element. Removing the element,
deleting a dynamic array, or replacing the whole container detaches the cell
after copying its last value. All outstanding references to the same live
element share one cell, so they remain aliases after detachment.

The cell supports 4-state and 2-state integral values, real values, strings,
and object handles. Containers hold only non-owning registrations and detach
all registered cells from their concrete derived destructor before their
element storage is destroyed; cells unregister when their final owning
handle is released. This avoids a container/cell ownership cycle and keeps
the old container pointer from surviving destruction.

Task string `ref` formals now use the bound wrapper too. `%load/str`, string
character writes, associative-array traversal keys, VPI reads/writes, and
generic string sends all delegate through it. Whole
container formals retain their existing copy-in/copy-out implementation and
its detached-fork warning; function string and real formals are unchanged.

## Permanent coverage

The focused legacy harness covers nine cases and the JSON/VVP harness covers
four directly changed or bounded paths. New tests verify:

- exact and variable-offset `[lo:$-offset]` queue slices;
- one evaluation of a side-effecting class-property receiver for both `$`
  slice forms;
- an exact compile-time diagnostic for the unsupported bounded-slice l-value;
- removed-element private reads and writes;
- live identity through `push_front` and `sort`, including a `wait` observer
  awakened by a write through the reference;
- two separately captured references remaining aliases after removal;
- bounded-tail removal and dynamic-array deletion;
- real, string, and object element storage;
- detached task-string `ref` writes, character writes, and associative
  `first`/`next` key updates;
- existing direct, property, fixed-word, and element ref bindings.

Final resource-capped results are 9/9 legacy and 4/4 JSON/VVP. Both new
positive sources build in Slang with zero errors and zero warnings; Slang
also accepts the explicitly documented l-value boundary source. The exact
two corpus sources compile and run under Icarus: `pop_back_assing.sv` reaches
its asserted values 2 and 4, and `persistence.sv` reaches all five asserted
values including the preserved 10.

The broader whole-container `ref` binding path remains open and loud for a
detached task branch. Element binding currently covers direct queue/dynamic
array variables; an element reached through a class property or other nested
container expression still takes the documented companion path. This change
does not claim full container-formal, nested-element, or function-formal
reference closure. Queue-slice X/Z bounds retain the pre-existing numeric
fallback and are not claimed as a newly closed boundary.
