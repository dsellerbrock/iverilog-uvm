# Session log — 2026-07-12 (fifth target): G10 array reduction methods

Engineering target: IEEE 1800-2017 7.12.3 array reduction methods
(`sum`, `product`, `and`, `or`, `xor`) and the 7.12.1 `min()`/`max()`
locators, over queues, dynamic arrays and fixed-size unpacked arrays,
with with-clause support — the G10 gap-audit cluster ("blocks
scoreboard reductions, RAL frontdoor").

## Starting evidence (reduced probe)

- `q.sum()` → `error: Method sum is not a queue method.`
- `d.sum()/product()/max()/min()` → `error: Method ... is not a
  dynamic array method.`
- `f.sum()` on a fixed array → silent "no method" compile-progress
  fallback returning 0.
- `q.and()` → syntax error (`and`/`or`/`xor` are keywords; no grammar
  rule for the call form).
- `q.xor with (item)` → parsed, but the `expr_primary K_with` fallback
  silently DROPPED the with clause, then the PEIdent path emitted
  `sorry: 'xor()' array reduction method is not currently implemented.`
- `q.find_index() with (...)` already worked (Phase 63b B1) on queues
  only.

## LRM grounding (1800-2017 PDF, clause 7.12, spec pp. 165-168)

- 7.12.3: reductions apply to "any unpacked array of integral
  values"; result type = element type, or the with expression's type;
  "the width of the reduction method result shall be the same as the
  width of the expression in the with clause" (the `bit_arr.sum with
  (int'(item))` example).
- 7.12.1: `min()`/`max()` return a QUEUE holding the best element
  (empty queue for an empty array); the with clause is optional.
- 7.12: "The scope for the iterator_argument is the with expression."

## Implementation

- **Elaboration** (elab_expr.cc): two new helpers next to the Phase
  63b locator builder — `make_array_reduction_expr_` (sfunc
  `$ivl_darray_method$reduce|<kind>`, parms: array, iter, idx, acc,
  value-expr; result type is a `netvector_t` with the with
  expression's width/signedness, else the element type's) and
  `make_array_minmax_expr_` (sfunc `$ivl_darray_method$minmax|<kind>`,
  parms: array, iter, result queue, idx, best, bestitem, value-expr).
  Dispatched from all three receiver branches of
  `elaborate_method_dispatch_` (queue — with an explicit `sorry` for
  assoc-compat receivers; dynamic array; fixed unpacked array — with
  an explicit `sorry` for multidimensional receivers).  `find*`
  locators now also route for dynamic and fixed arrays.  Non-integral
  elements are an error citing 7.12.3.
- **Receiver typing fix**: for `f.sum` on a fixed array,
  symbol_search reports the ELEMENT type (`net_type()`); the method
  receiver is the array itself, so `elaborate_expr_method_` now
  retargets `target_type` to `net->array_type()` when the reference
  is unindexed and the array is a `netuarray_t`.
- **Paren-less forms** (`y = b.sum;` — the LRM's own example syntax):
  these parse as plain member paths (PEIdent); an early hook in
  `PEIdent::elaborate_expr_` routes single-component
  reduction/min/max tails on integral-element array receivers to the
  same helpers.
- **Grammar** (parse.y): `and`/`or`/`xor` are keywords, so the
  generic call and with-clause rules cannot match them.  New rules
  per keyword: `.and()` call form, `.and() with (expr)`, and
  paren-less `.and with (expr)` (ditto or/xor), built by a new
  `pform_keyword_method_call` helper that fills
  `PECallFunction::with_constraints_`.  +6 shift/reduce conflicts
  (453→459), r/r unchanged at 1060; the conflicts are the intended
  shift-over-reduce at `K_with` after a keyword method name.
- **Per-call iterator binding** (the subtle one): the Phase 63b
  scheme created ONE hidden net named `item` per scope and reused it
  across sibling calls.  With mixed element types in one scope this
  poisons later calls: a signed 8-bit `item` from `byte b[]` made
  `u.max()` on `logic [7:0] u[$]` compare SIGNED (returned 0F instead
  of F0), and a 1-bit `bit` element store into the stale 8-bit net
  tripped `of_STORE_VEC4: val_size >= wid`.  Per 7.12 the iterator is
  scoped to the with expression, so each call now allocates a fresh,
  uniquely named iterator net and binds the user-visible name to it
  only while its with expression elaborates, via new
  `NetScope::set_signal_alias`/`restore_signal_alias` (netlist.h,
  net_scope.cc).  The same fix was applied to the pre-existing
  find_with locator builder.  Nested with-expressions bind correctly
  (innermost alias restored first).
- **tgt-vvp** (eval_object.c + eval_vec4.c dispatch + vvp_priv.h):
  `draw_array_reduce_vec4` emits an inline loop — accumulator
  initialized to the operator identity (0; 1 for product; ~0 via
  `%inv` for and), `%cmp/s` bound check, per-element load, value
  evaluation, fold with `%add/%mul/%and/%or/%xor` — leaving the
  result on the vec4 stack.  The minmax lowering tracks best value +
  best element with `%cmp/s` or `%cmp/u` chosen by the value
  expression's signedness (first element always taken; ties keep the
  earliest; x-flagged compares keep the current best) and pushes the
  best element into a fresh result queue (empty for an empty array).
  Receiver differences are hidden behind two helpers:
  queues/dynamic arrays use `%qsize` + `%load/dar/vec4`; fixed-size
  arrays use the compile-time word count + `%load/vec4a` (whole-array
  references arrive as IVL_EX_ARRAY, accepted alongside
  IVL_EX_SIGNAL).  The find_with loop shares the helpers, extending
  the locators to fixed arrays (vector elements only; explicit
  warning otherwise).  NO new vvp opcodes — existing bytecode only.

## Verified (permanent test `tests/g10_array_methods_test.sv`, 29 checks)

All three 7.12.3 LRM literal examples (`b.sum`=10, `b.product`=24,
`b.xor with (item+4)`=12, `bit_arr.sum with (int'(item))`);
queue/dynamic/fixed receivers; all four source forms; keyword methods;
signed (`min`=-7) and unsigned (`max`=F0) comparisons; with-clause
value remapping (`max() with (-item)` returns -7); empty-array
identities (sum 0, product 1, `max()` empty queue); custom iterator
names (`sum(x) with (x*3)`); fixed-array `find_index`; per-call
iterator binding regression (bit after byte in one scope).
Negative test `tests/negative/g10_reduction_non_integral.sv` (real
elements rejected citing 7.12.3).

## Remaining tail (explicit diagnostics, recorded in the gap audit)

sort/rsort/reverse/shuffle (7.12.2); unique on non-queue receivers;
assoc-array and multidimensional receivers (sorry); min/max on
string/real elements (sorry); `item.index`; class-property receivers
still take the older PEIdent property path.

## Regression evidence

Recorded in the checkpoint commit message (UVM suite, bundled ivtest,
negative suite 6/6, focused m6/g12 re-runs all PASS).
