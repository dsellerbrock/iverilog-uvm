# Session log — 2026-07-13: G10 tail — class-property receivers

Engineering target: array reduction/min-max/find* methods (IEEE
1800-2017 7.12) on CLASS-PROPERTY receivers — the dominant UVM shape
(scoreboard `this.q.sum()`, nested config chains `cfg.st.q.max()`).
The 2026-07-12e checkpoint covered receivers that symbol_search
resolves to a plain signal; UVM code is class-based, so property
receivers are what RAL/scoreboard idioms actually use.

## Starting evidence (reduced probes)

- `q.sum()` inside a class method, `sb.q.sum()` externally,
  `cfg.st.q.sum()` nested: elaboration routed them to the new G10
  dispatch (sub_expr is a NetEProperty), but the tgt-vvp loops index
  the receiver through a SIGNAL label (`%qsize v<sig>`,
  `%load/dar/vec4 v<sig>`) — shape check failed, 0/empty fallback.
- Paren-less property forms (`return q.sum;`, `c.q.sum`) took a
  different path entirely: the PEIdent class-property tail walker
  warned `Array method 'sum' on class-property darray/queue not yet
  supported (compile-progress: expression dropped)` and returned
  nullptr — the assignment silently evaporated (probe showed the
  TARGET VARIABLE keeping its previous value).

## Implementation

- **Elaboration** (elab_expr.cc): new `make_array_method_recv_net_` —
  when the receiver expression is not a NetESignal, allocate a hidden
  net of the CONTAINER type (netqueue/netdarray).  Only dynamic
  containers are object-valued, so fixed-size-array class properties
  get an explicit sorry.  All three builders
  (`make_array_reduction_expr_`, `make_array_minmax_expr_`,
  `make_queue_locator_with_expr_`) take the container type and pass
  the hidden net as an extra TRAILING sfunc parameter (parm 5 / 7 / 5)
  only when the receiver is indirect, so signal-receiver bytecode is
  unchanged.  The PEIdent class-property tail walker now routes final
  `sum/product/and/or/xor/min/max` components on non-assoc
  darray/queue properties to the same helpers instead of
  warn-and-drop.
- **tgt-vvp** (eval_object.c): new `draw_array_method_recv_` — a
  signal/whole-array receiver is used directly (old path); any other
  object-valued receiver is evaluated once with `draw_eval_object`
  and its HANDLE stored (`%store/obj`) into the hidden net, which the
  existing loop then indexes.  vvp queue/darray stores are by
  reference, so no copy is made.  Used by all three lowerings
  (reduce, minmax, find_with).

## Verified

`tests/g10_array_methods_test.sv` extended to 43 checks; the new
class-property section covers: method-internal call / paren-less /
with-clause / max / find_index-with; external `sb.q.sum()` and
paren-less `sb.q.sum`; nested chains (`cfg.st.q.sum()`,
`cfg.st.d.sum() with`, `cfg.st.q.and()`, `cfg.st.q.max()`,
`cfg.st.q.find() with`); empty property containers (sum 0, min empty
queue).  Reduced probes additionally verified byte-darray properties
and keyword methods on nested chains.

## Remaining G10 tail (gap audit updated)

sort/rsort/reverse/shuffle (7.12.2); unique on non-queue receivers;
assoc/multidim receivers (sorry); `item.index`; fixed-size-array
class properties (sorry).

## Regression evidence

Recorded in the checkpoint commit message (UVM suite, bundled ivtest,
negative suite, focused m6/g12/m3 re-runs).
