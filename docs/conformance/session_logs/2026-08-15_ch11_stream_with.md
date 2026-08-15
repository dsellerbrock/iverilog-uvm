# 2026-08-15 — Chapter 11 streaming `with` ranges

## Evidence and standard boundary

The pinned gap is the byte-identical sv-tests source
`chapter-11/11.4.14.4--dynamic_array_stream_with.sv`, SHA-256
`fdfefe171526ef7e48dba083df1f2d5c124aa5820afb5a5b4af55115279e3aeb`.
Slang `11.0.415+8acc660a2` accepts it with zero errors and warnings. IEEE
1800-2023 11.4.14.4 permits an unpacked-array or queue stream expression to
carry an optional index, range, `+:`, or `-:` selection. The range is
evaluated immediately before its corresponding field is packed or unpacked;
this ordering matters when earlier target fields change values observed by a
later range.

## Implemented immediate-blocking semantics

The parser retains the base plus both range expressions without increasing
the existing conflict profile. Elaboration validates one-dimensional
fixed/dynamic arrays and queues, integral range expressions, fixed-width
bit-stream elements, constant fixed-array bounds, and dynamic positive
indexes/widths. Constant indexed arithmetic uses `__int128`, so extreme host
values are diagnosed without signed overflow.

Target lowering evaluates an aggregate receiver first, then the first range
expression, then the width/right expression, each exactly once. Source and
target paths support ascending and descending fixed arrays with nonzero
bounds, dynamic arrays, bounded/unbounded queues, strings, whole and ranged
nested class properties, and indexed aggregate receivers. Explicit ranged
fields may precede one greedy unconstrained field. Fixed-array variable OOB
unpack stores only in-range elements and reports one error; source OOB
elements use the declared element default. `bit` containers and fixed-array
targets coerce X/Z to zero, while `logic` retains X/Z. Null property receivers
are no-ops with balanced object/vector stacks.

Range-derived flattened vectors are capped at 64 Mi bits. Object-backed
dynamic-array and queue targets have a separate 1,048,576-element cap because
their per-element storage is much larger than the payload bits; a rejected
resize preserves the previous container. Every source and target range-plan
consumer shares the same 1,048,576-element per-operation work cap, including
direct and property fixed-target store loops. Fixed-target declared indexes
are translated affinely in O(1) per element rather than rescanning the array.
Width and index plans use checked 128-bit arithmetic. VVP descriptor widths
and signed auxiliaries accept only complete in-range decimal spellings;
malformed bytecode emits one targeted error and produces an empty field rather
than allocating or asserting.

## Permanent coverage and differential

The 20-case focused legacy and JSON/VVP lists include:

- the byte-identical sv-tests source;
- all four selectors, fixed/dynamic/queue source and target paths, both
  declared directions, nonzero fixed bounds, resizing, mixed ranged/greedy
  fields, and direct fixed `bit` X/Z coercion;
- whole and ranged nested dynamic/queue/string/fixed properties, a null
  receiver, and source/target receiver-first-width evaluation order with one
  call per operand;
- X/Z ranges, variable fixed OOB clipping, bounded-queue truncation, constant
  OOB, an extreme constant range, nonintegral ranges, and illegal
  unconstrained-before-ranged ordering;
- max-plus-one dynamic-array/queue resize rejection, dynamic source/direct
  fixed target/property-target cap-plus-one recovery with value preservation,
  and a 32,768-element fixed target that pins linear rather than quadratic
  declared-index translation under the resource runner;
- the older unbounded dynamic-target controls and newly positive whole
  dynamic-property target.

Slang accepts the exact source, the property/evaluation-order test, the
runtime-variable boundary test, and the legal NBA residual. It rejects the
constant OOB, nonintegral, and unconstrained-before-ranged negatives with the
same polarity. Among normally bounded language-semantic cases in the added
11.4.14.4 matrix, NBA is the only Slang-accepted form that Icarus keeps
compile-time loud; the cap+1 fixtures separately expect resource-limit runtime
diagnostics. The `sv_stream_with_malformed_descriptor.vvp` raw-bytecode
fixture plus its exact gold pins an overflowed-width descriptor under the
resource runner.

Bison remains at 535 shift/reduce and 1115 reduce/reduce conflicts across 201
reported conflict states. The current conflict-descriptor lines have SHA-256
`2fe92c0b2d0130811277edacbd766bd126dca33615298cb303b665488f856df2`.

## Honest residual

This is not full streaming-assignment closure. A delayed/event-controlled or
nonblocking assignment to a run-time-sized/ranged streaming target needs the
receiver, both range values, source stream, and target identity snapshotted at
statement execution and stored only in the scheduled update region. That
aggregate NBA carrier is not present in this bounded change. These forms
therefore receive an exact compile-time `sorry`; they never execute as a
blocking assignment or re-evaluate later.
