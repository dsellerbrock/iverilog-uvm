# OpenTitan USBDEV queue range expressions (2026-08-24)

## Scope and standard rules

This increment separates queue range expressions from packed part selects and
from the superficially similar dynamic-array syntax. The relevant IEEE
1800-2017/2023 rules are distributed across four subclauses:

- 7.4.5 defines array indexing and slicing. A fixed- or dynamic-array slice
  has a fixed-size unpacked-array result. Its colon bounds are constant, its
  indexed width is a positive constant integral expression, and its range
  direction follows the array declaration.
- 7.4.6 preserves an array expression's aggregate type and shape through
  whole-array operations; a slice must not collapse into a scalar packed
  select or masquerade as a different container kind.
- 7.6 applies unpacked-array assignment compatibility and element-wise value
  assignment to that result. In particular, a dynamic-array receiver does not
  make its fixed-size slice result a dynamic array.
- 7.10.1 gives queues their distinct positional-range behavior. Queue colon
  bounds may be arbitrary integral expressions, the result is a queue, valid
  endpoints are clipped to the live queue, and reversed or unknown ranges are
  empty. The text explicitly illustrates the colon form. For queue `+:` and
  `-:`, this implementation follows Slang's interpretation that the queue
  arbitrary-bound exception applies to every range-selection kind; that is a
  recorded differential interpretation, not an unqualified 7.10.1 claim.

Slang's type model also establishes that a range selected from a bounded
queue has an unbounded queue type. The Icarus queue result therefore uses the
element type of the receiver but does not preserve the receiver's maximum
queue index.

## Root cause and implementation

OpenTitan USBDEV streams a run-time-selected section of a queue in
`usb20_monitor.sv`. The old expression walk reached the terminal colon range
through packed-select lowering, which imposed a constant-part-select rule
before recognizing that the receiver was a queue. The clean baseline stopped
at line 578 and repeated the same error at line 582:

```text
error: Part select expressions must be constant integral values.
```

The frontend now identifies a genuine non-associative queue before packed
residual handling. Direct, nested queue-of-queue, instance-property,
fixed-slot property, scoped static-property, method-result, untyped-display,
and streaming-expression paths share the container slice boundary. Colon,
indexed `+:`, and indexed `-:` forms retain the complete outer selection.

Queue-specific runtime operations evaluate the receiver and each bound/base/
width expression exactly once and in source order. Signed, unsigned, narrow,
wide, and X/Z operands are carried without truncating them to a host integer
or using them as an allocation size. Colon endpoints are clipped; indexed
ranges normalize into ascending queue order and clip to the live queue. An
unknown base, or a zero, negative, or X/Z indexed width, returns an empty
queue. Nested unpacked value elements are value-copied, so mutating a nested
container in the result does not alias the source. All queue range results are
fresh unbounded queues.

## Standards boundary and diagnostics

The same syntax must not silently reuse the queue result representation for
other unpacked containers:

- all associative-array colon, `+:`, and `-:` forms produce the exact error
  `associative arrays cannot be indexed by a range.`;
- legal dynamic-array colon and indexed r-values reach this exact loud
  boundary:

  ```text
  sorry: dynamic-array slice r-values are not yet supported as fixed-size unpacked-array expressions.
  ```

- invalid dynamic forms are diagnosed before that unsupported boundary:
  nonconstant colon bounds, `$` as an endpoint, reversed direction,
  nonintegral operands, and a nonconstant, nonpositive, or unknown indexed
  width;
- `$typename` and method contexts elaborate the dynamic slice and reach the
  same fixed-size-result boundary instead of silently claiming `int$[]`.

Queue slice l-values remain deliberately loud. The `$` token is supported as
a queue element or colon endpoint, including an arithmetic offset such as
`Q[lo:$-offset]`; using `$` as the base token of an indexed `+:` or `-:` range
remains a parser/lowering boundary and is not claimed by this increment.
Ordinary packed part selects retain their constant-bound requirements.

## Permanent coverage

`sv_queue_slice_variable_bounds` checks:

- colon, `+:`, and `-:` with run-time integral operands;
- exactly-once receiver, colon-bound, indexed-base, and indexed-width
  evaluation;
- signed and unsigned one-bit values plus 65- and 128-bit positive and
  negative values without truncation, wraparound, or over-allocation,
  including wide base/width cancellation that brings an endpoint back into
  the live queue range;
- endpoint clipping, reversed/wholly-out-of-range ranges, X/Z operands, and
  zero or negative indexed widths;
- direct, nested, selected-property, and scoped-static queue receivers;
- bounded receivers whose slice type is unbounded, plus bit, real, string,
  class-handle, and nested-container element storage;
- `.size()`, `$typename`, untyped formatting, and the USBDEV-shaped streaming
  operand;
- source independence for a slice whose elements are nested queues.

`sv_queue_slice_dollar_offset` retains the corpus `Q[0:$-1]` spelling and
proves that `$` is derived from the same exactly-once receiver evaluation.
`sv_queue_slice_nonintegral_bound_fail` pins the integral-operand diagnostics.
`sv_dynamic_array_slice_variable_bound_fail` and
`sv_associative_array_slice_fail` pin the standards boundary above, while
`sv_packed_part_select_variable_bound_fail` ensures the container fix does not
weaken packed-select rules. The focus lists also retain adjacent queue/ref and
`$` arithmetic coverage.

## Differential and regression validation

The differential oracle was Slang 11.0.448+e222e7dc0. Under both
`--std 1800-2017` and `--std 1800-2023`:

- the positive queue source builds with zero errors and zero warnings;
- the dynamic-array source accepts both legal slice expressions and rejects
  exactly the eight illegal expressions;
- the associative-array source rejects all three range spellings;
- an additional AST/type check gives both colon and indexed slices of a
  bounded queue an unbounded queue result.

The native arm64 compiler and VVP were rebuilt serially. No compiler or test
RSS cap was imposed; only the existing 45-second per-process CPU runaway guard
was retained. From `ivtest`, the relevant invocations are:

```sh
PATH="../local-install/bin:$PATH" perl vvp_reg.pl regress-ch7-queue-focus-legacy.list
PATH="../local-install/bin:$PATH" python3 vvp_reg.py regress-ch7-queue-focus-vvp.list
PATH="../local-install/bin:$PATH" perl vvp_reg.pl regress-sv.list
PATH="../local-install/bin:$PATH" python3 vvp_reg.py regress-vvp.list
```

The JSON harness must be invoked as `python3 vvp_reg.py`; it is not a Perl
script and should not rely on direct shebang execution. Final results were:

- focused legacy: 14/14;
- focused JSON/VVP: 9/9;
- complete `regress-sv.list`: 1,801/1,801;
- complete `regress-vvp.list`: 869/869;
- legacy queue-slice VVP bytecode compatibility: 3/3.

The two complete-corpus numbers are runner-reported test totals, not raw
manifest line counts.

Workspace-root-relative evidence is in
`evidence/opentitan-usbdev-variable-queue-slices-final-arm64-20260824T0232MDT/`.
The focused legacy, focused JSON, and legacy-bytecode logs have SHA-256 values
`ce9e82aab4e0c05f88ee6cdd6c6e4502a8a21bb0aa568cc7be1d9c1d89481aab`,
`d5ffa789e5abffc348abe50f4582c1a45ae99635833d1b0e210bd1fa268cff4c`,
and `32ef5d9a04ac8a0c2f5e31ff82afa655327c55709743fa518afc48c46ea40602`,
respectively. The identical 2017/2023 Slang positive logs have SHA-256
`413b5578d68013bbd10ed7bc9039c556070a486a02aced1e2e709e717f957b02`.

## OpenTitan USBDEV witness

The OpenTitan checkout remained unmodified at commit
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`. Recompiling the generated
`lowrisc:dv:usbdev_sim:0.1` graph finds no occurrence of
`usb20_monitor.sv:578`, `usb20_monitor.sv:582`, or the former constant-part-
select diagnostic. This proves removal of the two queue-slice blockers.

The graph still ends with ten unrelated elaboration errors. The later
blockers include hierarchical `usbdev_timed_regs.timed_reg_e` uses in
constant/cast-size contexts, three unsupported `std::randomize()` aggregate
constraint sites, and an unresolved `ep_default` statement. No VVP image or
USBDEV simulation was produced, so this is compile-frontier advancement, not
an OpenTitan pass or UVM-runtime claim. No OpenTitan source was changed.
`usbdev.stderr` has SHA-256
`10cbbf9e6d771aa61a893c82cca34e4a28cc9e15a6003575170557233bebd301`.

## Remaining boundaries

This increment does not implement queue range l-values, the indexed-`$`
parser form, or the fixed-size unpacked expression required for dynamic-array
slices. It also does not upgrade clauses 7.4, 7.6, or 7.10 to full
conformance. The dynamic-array gap is loud and type-correctly classified;
associative range selection remains illegal; and the OpenTitan timed-register,
randomization, and later USBDEV blockers are independent follow-on work.
