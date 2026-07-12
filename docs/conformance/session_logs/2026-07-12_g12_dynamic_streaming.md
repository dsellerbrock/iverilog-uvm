# Session log — 2026-07-12 (third target): dynamic-size streaming (G12 tail)

Engineering target: IEEE 1800-2017 11.4.14.4 — streaming operators with
dynamically sized operands and targets (queues, dynamic arrays,
strings), i.e. the two idioms the Accellera UVM library itself uses:

- `uvm_reg_map` byte<->bit queue conversion:
  `bits = {<< 8 {bit_q_t'({<< {p}})}};` and its inverse.
- `uvm_misc` string-queue join: `m_uvm_string_queue_join = {>>{i}};`

## Starting evidence (silent wrong data, no diagnostics)

All three reduced shapes compiled cleanly and produced garbage:
`bits.size()` was 2 instead of 16 (whole bytes copied into a "bit"
queue via the generic queue-copy path), the string join produced a
constant empty string (a netmisc compile-progress cast stub replaced
the whole expression with `NetECString("")`), and packing a byte queue
into a 16-bit vector produced `16'h8000` (the queue signal was
evaluated as a handle-null test).  Root cause: `PEIdent::test_width`
reports width 1 for a bare queue identifier and the static streaming
lowering trusted it.

## Design (grounded in the clause text retrieved last checkpoint)

Runtime stream builder in vvp, reusing existing machinery wherever it
existed:

- Flattening reuses the existing `vvp_darray::get_bitstream(bool)`
  virtual (already implemented for atom/vec4/vec2/real dynamic
  arrays); new overrides added for `vvp_queue_vec4`,
  `vvp_queue_string`, and `vvp_darray_string` (element 0 leftmost per
  the 11.4.14.1 foreach traversal; strings contribute 8 bits per char,
  first char leftmost).
- New opcodes (vvp/vthread.cc, compile.cc, codes.h):
  - `%stream/flatten/obj` / `%stream/flatten/str` — pop a container
    object / string, push its bit stream (null handles are skipped per
    11.4.14.1; empty containers yield a zero-width piece).
  - pieces are joined with the existing `%concat/vec4`.
  - `%stream/end/{l,r} <slice>, <tw>` — pack side: `<<` block
    re-ordering (11.4.14.2) plus fixed-target alignment when tw>0
    (left-align, zero-fill right; a wider stream is a runtime error
    per 11.4.14, recovering with the left-most bits).
  - `%stream/unpack/{l,r} <slice>, <tw>` — unpack side (11.4.14.3):
    consume the left-most tw bits (source narrower than the target is
    a runtime error), then the /l form applies the INVERSE block
    re-ordering ("the streaming operators perform the reverse
    operation").
  - `%stream/to/queue "<t>"` / `%stream/to/dar "<t>"` — materialize
    the stream as a container with the smallest element count that
    holds it (final partial element zero-filled on the right).
  - String results reuse the existing `%pushv/str` (drops NUL bytes,
    first stream byte becomes the first character).
- Elaboration (elab_expr.cc): dynamic streams lower to internal
  functions `$ivl_stream$pack$<l|r>$<slice>` /
  `$ivl_stream$unpack$...` (NetESFunc; typed result for
  container/string contexts).  Operand classification runs test_width
  and checks expr_type (DARRAY/QUEUE/STRING), with special handling
  for casts to dynamic types and nested streams.  Hook points:
  - `PEStreaming::elaborate_expr(ivl_type_t)`: container/string result
    types (covers queue/darray assignment targets — which flow through
    the net_type elaborate_rval_ overload — and casts).
  - `elaborate_pack_into` / `elaborate_unpack`: dynamic operands
    divert to the runtime builder with the target width.
  - `PAssign_::elaborate_rval_` (elaborate.cc): string targets build
    the string-typed stream function.
  - `PECastType::elaborate_expr(ivl_type_t)`: a dynamic streaming base
    cast to a dynamic type delegates to the streaming elaboration
    (previously the queue-cast "no-op" path silently passed the raw
    queue signal through).
  - The static width-context path routes dynamic operands to the
    runtime builder whenever the context provides a width (this covers
    class-property and array-element assignment targets, e.g. the
    `uvm_unpack_intN` macro's `VAR = {<<bit{__array}}` branch inside
    uvm_tlm2_generic_payload, which elaborates even when dead at
    runtime); a width-less plain expression context ERRORS with a
    clause reference (previously silent garbage).
- tgt-vvp: one shared emitter (`draw_stream_pack_pieces`) dispatched
  from the vec4, object, and string sfunc paths; the element type
  string for `%stream/to/*` comes from a helper factored out of
  `darray_new`.

## Verified semantics (probe matrix, all PASS)

Bit-exact `bits` image for the uvm_reg_map pair (E3FC for p='{C7,3F})
and exact round-trip; string join (uniform and non-uniform element
lengths); queue/darray targets from static streams (greedy resize);
unpack from a wider dynamic source (consume-from-left, plus `<<`
reverse); unpack into a queue operand; mixed static+dynamic operand
lists in both directions; empty-container operands; dynamic arrays as
operands and targets.

## Permanent tests

- `tests/g12_streaming_dynamic_test.sv` (15 checks, includes both UVM
  idioms verbatim).

## Remaining G12 tail (recorded in the gap audit)

`with [range]` stream expressions; streaming lvalues in continuous
assignments; struct/class operand flattening; class-property
containers as stream operands; multi-operand dynamic unpack beyond the
single-container case (greedy first-item rule).

## Regression evidence

Recorded in the checkpoint commit message (UVM suite + ivtest run in
this session).
