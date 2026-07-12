# Session log — 2026-07-12 (second target): G12 streaming concatenation

Engineering target: IEEE 1800-2017 11.4.14 streaming operators for
multiple operands — pack and unpack — removing the parse.y
compile-progress fallback family that silently produced wrong data.

## What the re-audit found (worse than recorded)

The gap audit recorded G12 as "streaming LHS drops all but the first
lvalue".  Reduced probes showed the whole family was degraded:

- `{>>{a,b,c,d}} = src` (unpack): parser rewrote to `a = {>>{src}}` and
  silently deleted b, c, d — no diagnostic at all.
- `y = {>>{a,b,c,d}}` (pack): parser kept only `a` (one warning).
- `{<< byte {...}}` (typed slice): silently treated as slice=1
  (bit-reverse instead of byte-swap).
- Pack used as assignment source relied on ordinary right-aligned
  padding/truncation, which contradicts 11.4.14's left-alignment rule.

## Grounding the semantics (manifesto: never invent semantics)

The published IEEE 1800-2017 text (clause 11.4.14 through 11.4.14.4)
was retrieved and the implementation checked against the normative
wording and every fixed-size literal example:

- 11.4.14.1: operands concatenate left-to-right into one generic
  stream — so a multi-operand stream is exactly an ordinary concat
  wrapped by the reorder step.
- 11.4.14.2: `<<` slices the stream into blocks **starting at the
  right-most bit**; a left-most partial block keeps the remaining
  bits; block order is reversed.  Examples `{<<4{6'b11_0101}}` =
  `'b0101_11`, `{<<2{{<<{4'b1101}}}}` = `'b1110` are in the test.
- 11.4.14.3 (unpack): "the streaming operators perform the **reverse**
  operation"; surplus source bits are consumed **from the left**
  (the `"hello world"` → a="hell", b="o wo" example); a too-small
  source **shall** be an error.  The reverse of the `<<` reorder is
  NOT the forward reorder when the slice does not divide the width —
  the implementation computes the true inverse so pack→unpack
  round-trips (probe: 20-bit value, slice 8).
- 11.4.14 (pack as assignment source): the stream is **left-aligned**
  in the target; narrower target is an error (`int j = {>>{a,b,c}}`
  example), wider target zero-fills on the right
  (`bit [99:0] d = {>>{a,b,c}}` example).

## Implementation

- `parse.y`: streaming rules build the operand list into a single
  expression (`pform_stream_operand`: one operand stays itself,
  multiple become `PEConcat`).  The three lvalue forms rewrite
  `{op N {lvals}} = rhs` into `{lvals} = {op N {rhs}}` with the
  streaming node marked lval-context (`pform_stream_lval_assign`);
  three new nonblocking (`<=`) forms added.  Slice size is now kept as
  an expression or a type and resolved at elaboration (parameters and
  `{<<byte{...}}` work).  Dead flag and the drop-operands warning
  removed.  Conflicts: 453 s/r (+3 from the new nonblocking rules,
  same benign shift-wins pattern as the existing forms), r/r unchanged
  at 1060.
- `PExpr.h` / `elab_expr.cc` (`PEStreaming`): `reorder_stream_` now
  implements forward and inverse block mappings; `resolve_slice_`
  evaluates constant slice expressions (explicit error when
  non-constant or non-positive) or type widths; `elaborate_unpack`
  implements 11.4.14.3 (error/consume-left/inverse-reorder);
  `elaborate_pack_into` implements the 11.4.14 left-alignment rules.
- `elaborate.cc` (`PAssign_::elaborate_rval_`): assignments whose rval
  is a streaming concatenation dispatch to the unpack or
  pack-alignment elaboration instead of ordinary rvalue width
  adaptation (covers blocking and nonblocking procedural assignments).

## Tests

- `tests/g12_streaming_concat_test.sv` — 15 checks including every
  fixed-size literal example from 11.4.14.2/.3, the non-dividing-slice
  round-trip, typed and parameter slices, wider-source unpack, pack
  left-alignment, nonblocking unpack, nested streams.
- `tests/negative/g12_stream_source_too_small.sv`,
  `tests/negative/g12_stream_target_too_small.sv` — the two LRM error
  examples must be rejected with a diagnostic.

## Explicitly out of scope (G12 tail, recorded in the gap audit)

Dynamic-size operands (queues/dynamic arrays/strings, 11.4.14.4 greedy
resize — used by uvm_reg_map byte packing and uvm_misc string join),
`with [range]` stream expressions, streaming lvalues in continuous
assignments, struct/class operand flattening.  Streaming concatenation
as a plain expression operand (LRM requires a bit-stream cast) remains
accepted as an extension with self-determined width.

## Regression evidence

- Focused: both reduced probes and the permanent test PASS; negative
  suite 5/5.
- Canonical + UVM: recorded at commit time in this log's checkpoint
  commit message (run in this session; see git history).
