# Session log — 2026-07-13 (sixth target): G09 completion — nested containers

Engineering target: close the G09 tail recorded by the previous
checkpoint — inner ASSOCIATIVE foreach dimensions and every
outer/inner combination of chained element access — plus the
value-semantics defect the work exposed.

## 1. Inner associative foreach dimensions (IEEE 1800-2017 12.7.3)

Previously an explicit sorry (the counting-loop descent cannot
iterate a keyed dimension).  `PForeach::elaborate_assoc_array_`
gained an `index_var_start` parameter so the first/next key descent
works at ANY dimension depth: the outer counting loop descends into
`elaborate_runtime_array_(…, index_var_start+1)`, and when the next
dimension is associative the assoc elaborator picks up from that
loop-variable index.  Verified shapes: `foreach (aa[k1, k2])` over
`int aa[int][string]`, string-keyed-outer/int-keyed-inner, and
queue-outer/assoc-inner (`foreach (qa[i, k])`).

## 2. Chained keyed reads through positional outers

`qa[0]["a"]` (queue-of-assoc) mis-lowered: the chained-select
root-derivation guards in tgt-vvp (eval_vec4.c, eval_string.c)
required the ROOT signal to be an assoc-compat queue, so a plain
queue root never took the keyed branch — the emitted code loaded the
OUTER queue handle and used the inner key as a positional index
(`%ix/vec4 3` clobbered the outer index; `%load/qo/v` read element
"a"=97 of the outer queue → 0).  Fix: derive the sub-select's type
from ANY container root (queue or darray) — the branch below still
requires the derived ELEMENT type to be assoc-compat, so plain
queue-of-queue stays positional.  `%load/dar/obj` already indexes by
word 3, so the element handle load was correct once the guard fired.

## 3. Chained element stores: all four outer/inner shapes

The `$ivl_assoc$store2` rewrite fired only for assoc-compat outers.
Probing all four combinations found silent wrong answers in three:

| shape                 | before                              |
|-----------------------|-------------------------------------|
| `aa[k1][k2] = v`      | ok (previous checkpoint)            |
| `aq[k][i] = v`        | SILENT NO-OP (keyed %aa/store into a queue receiver) |
| `qa[i][k] = v`        | row CLOBBERED (lval fallback)       |
| `qq[i][j] = v`        | row CLOBBERED (lval fallback)       |

The elaboration rewrite now fires for any queue-typed outer with a
container element (guarded against static-array-of-container
signals, whose first tail index selects the array word).  The
lowering picks the outer access (keyed `%aa/viv/sig` with
auto-vivification vs positional `%load/dar/obj`, no vivification —
an out-of-range positional row yields a nil handle and the store is
skipped) and the inner store (keyed non-sig `%aa/store` vs the NEW
`%store/qo/i/{v,r,str,obj}` opcodes: indexed element store through a
queue receiver popped from the object stack, index in word 3,
`set_word_max` semantics — appends at index==size, warns
out-of-range, same as the signal-based `%store/qdar` forms).

## 4. Value semantics of container element stores (7.6, 7.9.9)

`qa.push_back(t)` and `aa2[k] = u` stored the SOURCE HANDLE: later
mutation of `t`/`u` reached the stored element ("Assigning an
associative array to another associative array causes the target
array to be cleared of any existing entries, and then each entry in
the source array is copied" — 7.9.9; queues/darrays copy per 7.6).
Top-level assignment (`b = a`) already copied; only element stores
aliased.  Fix: `container_value_copy_()` in vvp — duplicate the
value at the store when it is a container (vvp_darray/vvp_queue/
vvp_assoc_base); CLASS HANDLES STILL ALIAS (a handle is the value).
Wired into every element-store site that accepts object values:
`aa_store_{str,obj,vec}`, `aa_store_signal`, `store_qb`, `store_qf`,
`store_qo_b`, the new `store_qo_i`, `%store/dar/obj`,
`%store/qdar/obj`.  The `%aa/viv/*` path is untouched (it must push
the SAME handle it stores, for subsequent in-place mutation).

## Verified (permanent test `tests/g09_nested_container_test.sv`, extended to 34 checks)

Inner-assoc 2D foreach (assoc-of-assoc int/string keys both orders);
queue-of-assoc chained reads, 2D foreach, inner key traversal order;
string values through positional-outer chains; chained stores for
all four shape combinations with neighbor-preservation checks;
push_back copy and keyed whole-container store copy (source mutation
does not reach the stored element).

## Remaining tail (gap audit updated)

Indexed-element method calls in EXPRESSION context (`aq[k].size()`,
`qa[i].num()` constant-stubbed to 0); 3-deep chains (%aa/viv/o/*
runtime exists, codegen unreferenced); object-valued chained reads
in object context; darray (`new[]`) outers in the store2 rewrite
(netqueue-typed outers only today); deep copy of container-of-
container VALUES on element store is one level (matches existing
top-level duplicate semantics).

## Regression evidence

Recorded in the checkpoint commit message.
