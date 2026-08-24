# OpenTitan DMA fixed-property slice l-values (2026-08-24)

## Scope and standard rules

OpenTitan DMA declares this non-static class property:

```systemverilog
bit [TL_DW-1:0] exp_digest[16];
```

At frozen OpenTitan commit `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`,
`dma_scoreboard.sv:1446` and `:1450` contain the direct writes
`exp_digest[8:15] = '{default:0};` and
`exp_digest[12:15] = '{default:0};`.

IEEE 1800-2017/2023 7.4.5 and 7.4.6 make an unpacked-array range a
fixed-size unpacked-array selection. A colon slice has constant endpoints;
an indexed slice has a positive constant width, while its base may generally
be variable. Only one unpacked dimension is sliced, and the result direction
follows the declaration. Sections 7.6 and 10.4 map array assignments
left-to-left in declared order. Section 10.9.1 context-types the assignment
pattern from the selected l-value, so the `default` fills that selected range
rather than the whole property.

The supported subset is deliberately narrower: direct non-static
one-dimensional properties, constant colon or constant-base indexed ranges,
simple blocking assignment-pattern values, and packed integral, real, or
string leaves. Compile-time rejection of a constant out-of-range range is the
current strict implementation boundary; it is not claimed as an additional
IEEE rule.

Slang 11.0.448+e222e7dc0 accepts the supported reducer under both
`--std 1800-2017` and `--std 1800-2023`. Its AST gives both the selection and
the contextual pattern a `FixedSizeUnpackedArrayType`; indexed-result polarity
follows the declaration direction.

## Root cause and implementation

The object-backed property l-value path installed the property and then sent
every following selector to scalar word-index canonicalization.
`indices_to_expressions()` intentionally rejects range selectors, producing
the two `Array cannot be indexed by a range.` errors.

The fixed-slice decoder is now usable against either a signal or an already
resolved property type. Before scalar indexing, the property path recognizes
a final one-dimensional `[:]`, `[base +: width]`, or `[base -: width]`, checks
its direction and bounds, builds the selected `netuarray_t`, and stores the
constant canonical-low property word in `NetAssign_::set_array_slice()`.
Assignment-pattern elaboration already normalizes descending source order to
canonical storage order, so the VVP target does not reverse it again.

The opaque target l-value now exports `ivl_lval_is_array_slice()`, analogous
to the existing queue-slice accessor and included in `ivl.def` for Windows.
The explicit bit is important: an ordinary scalar index into a property whose
element is itself a fixed-array typedef also has a fixed property type, fixed
result type, and index. Inferring a slice from those types generated corrupt
stores. Both that scalar-prefix form and an outer range above a nested fixed
element are now rejected before target lowering.

For a supported slice, VVP evaluates the receiver once. It snapshots every
RHS pattern leaf onto its type-specific stack before issuing any property
store, then pops and stores in canonical order. This preserves overlap/swap
semantics as well as untouched property words. Existing whole-property
integral, real, and string pattern writers now use the same two-pass capture,
fixing their latent aliasing order at the same time. No VVP opcode or runtime
allocation was added.

Property-slice NBA is rejected during elaboration. Without that guard, a
one-element base-zero slice could be mistaken for a root class-handle signal
word by the existing array-pattern NBA lowering.

## Permanent coverage

`sv_class_fixed_uarray_slice_lval_pattern` value-checks:

- both exact OpenTitan `[8:15]` and `[12:15]` default-zero writes and
  untouched prefixes;
- one-element and descending positional patterns;
- negative/nonzero declared bounds and both indexed polarities on ascending
  and descending declarations;
- a side-effecting receiver evaluated once;
- overlap swap with complete-RHS snapshot semantics;
- real and descending string property slices.

`sv_class_fixed_uarray_slice_lval_fail` pins exact diagnostics for opposite
direction, constant out-of-range selection, runtime indexed base, NBA, and
both typedef-nested fixed-array prefix forms. The tests are in both main
harnesses, both unpacked-slice focuses, and both OpenTitan fixed-container
focuses.

The legacy VVP queue-slice runner also no longer hard-codes a repository
`local-install/lib/ivl` module directory. An optional `VPI_MODULE_DIR` is
validated when supplied; otherwise the installed VVP runtime uses its
compiled-in module path. This fixes the Ubuntu CI staging layout without
changing queue semantics.

## Native ARM64 validation

The branch started exactly from merged `origin/main`
`8f7ab1ba4195a321d07752462c0a49f500a52f69`. The compiler and targets were
built serially with Homebrew ARM64 dependencies, `-g0 -O2`, and the branch's
own `local-install`. No RSS or compiler-size limit was imposed; the shared
runner retained only `ulimit -t 45` as a per-process CPU runaway guard.

The UVM submodule is not automatically populated in a fresh Git worktree.
Before using `-uvm`, run `git submodule update --init -- uvm-core` and then
`make -j1 installuvm`; otherwise the frontend correctly reports the missing
`local-install/lib/ivl/uvm/src/uvm_pkg.sv`. The JSON harness invocation is
`python3 vvp_reg.py`, and `make -C tgt-fpga install` must precede its complete
manifest. These are invocation/provenance gotchas, not language failures.

Final results:

- unpacked-slice focus: 18/18 legacy, 15/15 JSON/VVP;
- OpenTitan fixed-container focus: 17/17 legacy, 17/17 JSON/VVP;
- complete `regress-sv.list`: 1,803/1,803;
- complete `regress-vvp.list`: 871 records, zero failures;
- `make check`: passed;
- real-DPI UVM sweep: 338 passed, zero failed, zero skipped;
- exact DMA reducer: compile and runtime pass;
- legacy queue-slice bytecode compatibility: 3/3.

## Unmodified OpenTitan witness and next frontier

The frozen `lowrisc:dv:dma_sim:0.1` source list was replayed unchanged from
the prior evidence build directory with the freshly installed compiler and
UVM tree. Compilation returns zero. Neither `dma_scoreboard.sv:1446` nor
`:1450` appears, and there is no `Array cannot be indexed by a range.`

The graph advances into the VVP target and exposes a later independent
frontier: calls to `clk_rst_if.apply_reset` and
`clk_rst_if.drive_rst_pin` report that selected virtual-interface receiver
instances have no argument row. Those target errors must be fixed before the
DMA image is a trustworthy runtime witness. This result closes the two
property-slice blockers, not the complete DMA graph or simulation. No
OpenTitan or Caliptra source was changed.

## Remaining boundaries

- runtime-base indexed property slices;
- multidimensional and typedef-nested property slices;
- static-property and general aggregate-member variants;
- property-slice r-values and non-pattern array/function sources;
- nonblocking, delayed, compound, and other non-pattern stores;
- assignment-pattern leaves requiring aggregate/object value semantics;
- opposite-direction fixed-slice subroutine copy-in/copyback outside this
  property-lvalue path.

Each recognized unsupported form is kept loud; none is intentionally lowered
as a scalar property word.
