# OpenTitan HMAC dynamic-array slice r-values (2026-08-24)

## Scope and standard rules

The unmodified OpenTitan HMAC sequence contains this direct self-slice:

```systemverilog
test_vectors_pkg::test_vectors_t parsed_vectors[];
...
parsed_vectors = parsed_vectors[0:1];
```

`test_vectors_t` is an unpacked value struct containing integral and string
members plus several dynamic-array members. The old compiler stopped at
`hmac_test_vectors_sha_vseq.sv:82` with the single hard diagnostic:

```text
sorry: dynamic-array slice r-values are not yet supported as fixed-size unpacked-array expressions.
```

The ignored local IEEE 1800-2023 reference was verified at SHA-256
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`.
The rendered 7.4.5 and 7.6 pages establish the rules used here:

- a slice selects contiguous elements, and an unpacked-array slice remains an
  unpacked array;
- slice size is constant although an indexed slice position may vary, and only
  one array dimension is sliced;
- an invalid source element index reads the element type's default value;
- fixed/dynamic/queue array assignment requires equivalent element types; a
  fixed target or target slice additionally requires equal element counts;
- elements correspond left-to-right, and a dynamic-array target resizes to the
  source expression's element count before receiving the values.

This increment deliberately implements only the direct constant-colon form
needed by HMAC. It does not use queue semantics for a dynamic-array result.

## Root cause and implementation

The expression frontend already recognized dynamic-array colon and indexed
ranges and correctly refused to call them dynamic arrays, but it had no
fixed-unpacked aggregate representation that the dynamic-array assignment
path could consume.

For an immediate blocking whole assignment to a direct one-dimensional plain
dynamic-array signal, the assignment elaborator now recognizes a direct plain
dynamic-array signal source with one `left:right` selector. It requires fully
defined constant integral bounds, the implicit ascending dynamic-array
direction, signed 64-bit source indices, a host-representable result count,
and bidirectionally equivalent source/target element types. Every generated
source index is an exactly 64-bit signed `verinum`, so LP64 values cannot be
truncated to the normal 32-bit integer width. The synthetic fixed result uses
the canonical ascending range `[0:count-1]`; only its element sequence and
count are observable when assigning to a dynamic array, and this avoids
putting a 64-bit source coordinate into `netrange_t` on LLP64 Windows. The
result is carried by a `NetEArrayPattern` of typed dynamic-array element reads,
reusing the target's existing element-wise construction.

Two VVP ordering defects were load-bearing:

1. Ordinary dynamic-array pattern assignment allocated and stored the new
   destination before evaluating pattern leaves. In `a = a[0:1]`, that erased
   the receiver before the first source read. The target now materializes the
   complete RHS container first and replaces the destination only afterward.
2. The container-pattern builder loaded its destination element index into
   word register 3 before evaluating the source leaf. A source dynamic-array
   select also uses register 3, so `dst = src[1:2]` stored values into the
   source-index positions. Each vector, real, string, and object branch now
   evaluates its leaf first and reloads the destination index immediately
   before `%store/qo/i/*`.

No new VVP opcode or runtime container kind was required.

Object-valued OOB reads exposed two further representation requirements. The
container-pattern builder now attaches the existing `%dar/elem/proto`
metadata when its element is an object-backed value struct. A default nil
slot can therefore materialize the struct's integer/string/nested-dynamic-
array defaults even after the completed container is copied into a class
property; class-handle arrays intentionally receive no prototype. The direct
signal `%load/dar/obj` path now checks both the live size and `UINT_MAX` before
calling the runtime's unsigned-index `get_word`, so a positive 64-bit OOB
coordinate cannot wrap onto element zero.

## Permanent coverage

`sv_dynamic_array_slice_rvalue` is registered in both main manifests and both
chapter-7 queue/slice focus manifests. It value-checks:

- a non-self `int` slice with nonzero source bounds;
- explicit `bit`, `int`, four-state, real, and string out-of-range defaults;
- signed `+/-4294967296` singleton source indices that would alias element
  zero if their generated constants were truncated to 32 bits;
- an integral self-slice, proving complete-RHS snapshot ordering;
- nonzero-base real and string slices, exercising their distinct store paths;
- a HMAC-shaped unpacked struct containing an integral member, a dynamic byte
  array, and a string;
- non-self unpacked-struct copy independence by mutating the copied scalar,
  nested dynamic-array element, and string while the source remains unchanged;
- partial- and all-OOB unpacked-struct defaults copied through a class dynamic-
  array property, including integer, string, and nested-dynamic-array members;
- a far-positive object index above `UINT_MAX`, proving it cannot wrap onto a
  populated source element;
- class-handle identity for an in-range element and a null OOB neighbour;
- unpacked-struct self-slicing with nested-member values preserved.

`sv_dynamic_array_slice_variable_bound_fail` now accepts its direct
constant-colon control and retains exact diagnostics for the legal indexed
form that is not implemented yet, nonconstant/unknown/reversed/queue-only
bounds, nonpositive or nonintegral indexed operands, inequivalent element
types, and the still-loud nested-property form. The first and last of those
plus unpacked-union elements are implementation boundaries; the other ten are
standards-negative forms. Unpacked unions are rejected before aggregate
lowering because the current shared union storage initializes to X whenever
any member is four-state instead of implementing Table 7-1's first-member
default rule.

Slang 11.0.448+e222e7dc0 accepts the shared positive source with zero
diagnostics under both `--std 1800-2017` and `--std 1800-2023`. Slang limits a
dynamic-array index to signed 32-bit and rejects the three wider constants, so
those Icarus code-generation checks are explicitly guarded by `__ICARUS__`;
they run in both permanent Icarus harnesses without making the common semantic
oracle platform-dependent. Slang rejects exactly the ten standards-negative
lines in the negative source while accepting the legal indexed-variable,
nested-property, and unpacked-union expressions that remain focused Icarus
implementation boundaries.

## Native ARM64 validation

Affected objects, the full local build, and the local install were built
serially through `evidence/arm64-tooling/resource-runner`. The current
worktree's compiler/runtime were used; there was no VM and no compiler RSS
limit. The focused results are:

- legacy chapter-7 focus: 15/15;
- JSON/VVP chapter-7 focus: 10/10.

The final complete manifests report 1,862/1,863 legacy tests and 932 JSON/VVP
tests with one failure. Both failures are the same
`sv_constraint_fixed_array_reduction` stderr-gold mismatch. Replaying its
three-test focus against the untouched mainline compiler at `6aa13fcf` gives
the identical failure, so it is inherited deterministic constraint-lowering
debt rather than a dynamic-array-slice regression.
`make check` passes, the bundled VPI suite passes 99/99, and the exact
negative-diagnostic suite passes 123/123. The full real-DPI UVM suite passes
338/338 with no failures or skips.

The exact frozen HMAC source graph was then replayed from the prior FuseSoC
work root with the original `-g2012 -stb -uvm` defines and source command file.
The prior result was exit 1 with exactly the line-82 slice blocker. The final
compile exits 0 in 3.10 seconds wall time, emits a 60,109,659-byte VVP image,
and contains no hard errors. A native ARM64 build of OpenTitan's unmodified
`cryptoc_dpi` sources and the generated DPI-export stub also succeeds.

The real-DPI smoke run is not yet a pass. It reaches `hmac_base_test`, then at
0 ps reports one primary `RspZero_A` failure at
`tlul_rsp_intg_gen.sv:82`; UVM raises `BUILDERR` and finishes. The subsequent
256 `noOutstandingReqsAtEndOfSim_A` reports are shutdown fallout from that
zero-time abort. The process exits 0 because UVM calls `$finish`, but the UVM
report and `TEST FAILED CHECKS` banner are authoritative. A reduced diagnostic
shows the next compiler frontier is VVP nested-concatenation initialization:
a parent concat can publish its initial value before every child input has
delivered, transiently exposing Z in `rsp_intg` bits OpenTitan drives to zero.
No OpenTitan source was modified.

Evidence is in
`evidence/opentitan-hmac-darray-slice-final-arm64-20260824/`.
`matrix-compile.log` has SHA-256
`f681e37e39ea84f4e469238d07cfe0d6f6917f559be8b470d2c043729d3d4209`;
`matrix-uvm.vvp` has SHA-256
`8699b3c7e29a87c4f6a0609e80d1806c63709d8b0f8dd078b8a00ebcb29e3b5c`;
and `matrix-runtime.log` has SHA-256
`1df81a2222fb5a4208801186c9c875ccd0a94a763ff0d34828059886f7e7769a`.

## Follow-up: nested-concatenation initial delivery

The historical compile, runtime result, and hashes above are unchanged. A
same-day follow-up reduced and fixed the next frontier in VVP: `.concat` and
`.concat8` now wait for one delivery from every connected input port before
their first publication. The internal accumulator remains intentionally
Z-filled for partial-vector semantics, and an all-Z final initial delivery
still forces publication. The exact reducer changes from three callbacks with
`rsp_intg=zzzzzzz` in the first callback to two callbacks with zero integrity
bits throughout. The unmodified HMAC smoke no longer reports `RspZero_A` or
its UVM `BUILDERR`; after the adjacent boolean-`dist` solver correction it
advances to 696084 ps and a later scoreboard `is_idle` mismatch. This is not a
whole-HMAC pass, and no OpenTitan source was modified. See the
[concat initial-delivery session log](2026-08-24_opentitan_concat_initial_delivery.md).

## Remaining boundaries

This is not a general dynamic-array slice-expression implementation.
Run-time-position indexed `+:`/`-:` slices, property/nested receivers, fixed
array targets, standalone expression/type-query/method/argument contexts,
multidimensional shapes, delayed/event-controlled/NBA assignments, and
compound assignments remain on their existing loud paths. Unpacked-union
elements also remain a focused `sorry`; this increment does not broaden global
union default runtime semantics. Bounds outside the signed 64-bit range and
result counts whose canonical fixed range is not host-representable remain
explicit implementation limits. Queue ranges retain their separate queue-
valued semantics, and associative-array ranges remain illegal.
