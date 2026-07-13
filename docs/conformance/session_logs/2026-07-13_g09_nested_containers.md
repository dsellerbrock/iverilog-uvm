# Session log — 2026-07-13 (fifth target): G09 nested dynamic containers

Engineering target: the G09 family — nested dynamic containers
(assoc-of-queue, assoc-of-assoc, queue-of-queue).  The audit symptom
("2D foreach iterates 0 times") turned out to be three layered
defects, only the last of which was in foreach itself.

## Root-cause chain (reduced probes at every step)

1. **Dimension composition inverted** (elab_type.cc
   `elaborate_array_type`): mixed unpacked dimension lists were
   composed LEFT-to-right, so `int aq[int][$]` built a plain queue of
   assoc arrays (outer `assoc_compat=false`) instead of an
   associative array of queues.  IEEE 1800-2017 7.4.5/20.7: the
   rightmost dimension varies most rapidly — it is the innermost
   type.  Identical-kind nestings (`[$][$]`) accidentally survived;
   every mixed declaration was silently wrong, poisoning ALL
   downstream keying: `aq[5].push_back(10)` lowered to a positional
   darray load, foreach used %qsize on an empty queue, etc.  Fixed by
   composing right-to-left (static runs still collapse into one
   unpacked-array type in source order).
2. **Chained element stores dropped the inner key** (elab_lval.cc
   `elaborate_lval_darray_bit_` "ignore trailing index" fallback):
   `aa[k1][k2] = v` degenerated to `aa[k1] = <null>`.  UVM depends on
   this shape (uvm_report_server `m_streams[a][b] = stream`,
   uvm_printer/recorder `m_recur_states[value][policy] = ...`).
   Fixed by a PAssign::elaborate rewrite to a new internal system
   task `$ivl_assoc$store2(outer, k1, k2, value)`; the code generator
   lowers it to an auto-vivifying element access plus a keyed store
   through the element handle (the non-sig `%aa/store/<val>/<key>`
   forms peek their receiver from the object stack, so no hidden nets
   are needed).  The store kind follows the DECLARED inner element
   type (string literals arrive as packed vectors and are converted
   with `%pushv/str`).
3. **Chained reads mis-lowered**: `aa[k1][k2]` in vec4 context lacked
   an integral-key branch and the existing assoc branch never fired
   because chained selects carry no net_type (now derived from the
   root signal's element type); string context had no chained branch
   at all (empty-string fallback) — both fixed with keyed
   `%aa/load/{v,str}/<key>` loads through the element handle.
4. **Inner associative foreach dimension**: the counting-loop descent
   cannot iterate an assoc dimension (the loop variable has the key
   type; the integer step degenerates via the compound-string-skip
   fallback and the loop NEVER TERMINATES — the composition fix
   turned the old silent 0-iteration into a hang).  Now an explicit
   sorry; first/next-based inner iteration is the recorded tail.

## New runtime primitive

`%aa/viv/sig/{v,str} <asig>, <spec>` and `%aa/viv/o/{v,str} <spec>`
(vvp/vthread.cc): pop the key, load the element handle from an
object-valued associative array, CREATING and inserting an empty
inner container per the spec code (0-3 queue of vec4/real/string/
object, 4-7 the assoc equivalents) when the key is absent; push the
element handle.  The sig/{v,str} forms are emitted by
`$ivl_assoc$store2`; the o/* forms are the foundation for 3-deep
chains (currently unreferenced by codegen).

Note: `aq[k].push_back(v)` auto-vivification already existed in
tgt-vvp (`show_queue_object_receiver`) — it was unreachable solely
because of the type-composition inversion.

## Verified (permanent test `tests/g09_nested_container_test.sv`, 15 checks)

queue-of-queue 2D foreach; assoc-of-queue chained push_back /
push_front (the uvm_resource_pool::sort_by_precedence idiom), element
reads, 1D and 2D foreach (aq2=33); assoc-of-assoc chained stores and
reads for int and string values (the report_server/printer shape),
overwrite stability; string-keyed × string-keyed × string-valued
nesting.

## Remaining tail (gap audit updated)

Inner associative foreach dimension (explicit sorry — needs
first/next descent with key-typed loop variables); indexed-element
method calls in EXPRESSION context (`aq[5].size()` still
constant-stubbed to 0); 3-deep chains; object-valued chained reads in
object context.

## Regression evidence

Recorded in the checkpoint commit message.  The composition fix is
global to all declarations — full UVM + ivtest gating mandatory.
