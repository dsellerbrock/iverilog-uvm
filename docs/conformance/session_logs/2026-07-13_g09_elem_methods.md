# Session log — 2026-07-13 (seventh target): indexed-element container method calls

Engineering target: the last big G09 residual — container method calls
on INDEXED-ELEMENT receivers (`aq[k].size()`, `qa[i].num()`,
`aa[k].exists(x)`, `aq[k].pop_back()`, `qa[i].delete(key)`, ...) were
compile-progress stubs: constant 0 for size/num, null for the rest,
and a silent positional mis-delete for keyed deletes.

## Root causes (three, layered)

1. **Dispatch guard**: every container-method family in
   `elaborate_method_dispatch_` was gated on `!target_indexed`.  For
   an indexed receiver the target type is the ELEMENT type; when that
   element is itself a dynamic container the element expression IS a
   valid container receiver (7.12 applies to any unpacked array
   expression) — dispatch now proceeds exactly as for an unindexed
   receiver.  The lowering paths already evaluate non-signal
   receivers through the object stack (`%qsize/o`, `%qpop/o/{b,f}`,
   non-sig `%aa/exists|first|next|delete`, and the reduction/locator
   recv-net machinery from the property-receiver work).
2. **test_width class-null bailout** (the assignment-context
   divergence): `r = aq[5].pop_back()` was constant-folded to 0
   BEFORE elaboration — `PECallFunction::test_width`'s indexed branch
   knew only string-element methods, so pop_back/find fell through to
   the class-null compile-progress stub type, and `elab_and_eval`
   substitutes `make_const_0(1)` for class-typed expressions in
   scalar contexts without ever elaborating the call.  The indexed
   branch now mirrors the unindexed container method table
   (size/num, exists/traversal, pop_back/pop_front with the inner
   element's type, find*/min/max/unique as queue-typed).  Display
   contexts never hit this because a no-type result falls through to
   real elaboration — which is why the same call worked in `$display`
   but not in an assignment.
3. **Keyed delete on assoc elements** (`qa[0].delete("a")`): the
   object-receiver delete lowering treated every 2-parm delete as
   positional (`%delete/o/elem` with the key cast to an index) — a
   silent no-op.  Now the receiver's container type is derived (own
   net_type, or the root signal's element type for one-level selects)
   and assoc-compat receivers emit the keyed `%aa/delete/<kind>`
   through the element handle (7.9.2).

## Bonus general conformance fix: exists() return value (7.9.3)

The probe exposed a defect in ALL exists() paths (signal receivers
included): the runtime built the result as `vvp_vector4_t(wid, BIT4_1)`
— every bit set — so `aa.exists("x")` evaluated to 4294967295 and
`aa.exists("x") + 1` to 0.  7.9.3: exists() returns 1 or 0 (an int).
All four runtime helpers now zero-fill and set only the LSB (the
traversal helpers had already been fixed the same way).

## Verified (permanent test `tests/g09_elem_methods_test.sv`, 32 checks)

size/sum/num on queue and assoc elements (expression, assignment and
operand positions); exists hit/miss and the `exists()+1 == 2` value
shape; first/next traversal on an assoc element; pop_back/pop_front
through the element handle with mutation visible (both syntactic
contexts); find/find_first_index/min/max with with-clauses on
elements; string-keyed outer dimensions; statement-context sort,
positional delete, delete-all and KEYED delete on elements; class
elements (property and method calls) unaffected.

## Remaining tail

3-deep chains; object-valued chained reads in object context; darray
(`new[]`) outers; `%0d` display of the queue result of min()/max()
prints 1 (pre-existing, identical for signal receivers — the LRM
return type is a queue, use `q = x.max(); q[0]`).

## Regression evidence

Recorded in the checkpoint commit message.
