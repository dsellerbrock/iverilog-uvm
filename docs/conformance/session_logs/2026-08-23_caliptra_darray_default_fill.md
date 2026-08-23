# Caliptra dynamic-array constructor default fill (2026-08-23)

## Scope and source

- Base: `origin/main` at `0cc83473651acfdbfd1fc649afe080ae732b7c19`.
- External Caliptra and OpenTitan checkouts were read only.
- Reduced from Caliptra
  `src/integration/tb/caliptra_top_tb_soc_bfm.sv:433`:

  ```systemverilog
  wstrb_array = new[FW_NUM_DWORDS]
      ('{default:{`CALIPTRA_AXI_DATA_WIDTH/8{1'b1}}});
  ```

- IEEE 1800-2017/2023 clauses 7.5.1 and 10.9.1 require the `new[N]`
  context to size the assignment pattern and the default key to cover every
  unmatched element. The default expression's side-effect evaluation count
  is intentionally unspecified by 10.9.1.

## Defect and implementation

Icarus lowered the lone-default pattern as a one-element positional pattern.
For Caliptra, element zero became all ones and the other 255 four-state
elements remained unknown. It also emitted an unrelated 7.9.11 container
fallback warning.

`PENewArray` now elaborates the default in the destination element's type and
preserves a typed internal marker. The VVP target evaluates the value once and
emits one compact fill instruction, so constant size 256 does not create 256
copies of the expression and a run-time size works identically. Integral,
real, string, class-handle, and object-backed value elements use their native
runtime stacks. Object fills retain class-handle identity and independently
copy structs and nested containers.

The four new runtime instructions validate stack depth and receiver kind.
Malformed hand-written bytecode is diagnosed and ignored instead of reaching
an assertion or invalid stack access. This is a preventative robustness
boundary; no memory-safety failure was observed in the legal-source tests or
the eight malformed-bytecode reproducers.

## Focused evidence

- Pre-fix reduced evidence: 2/5 language-focus tests passed; both positive
  constructor tests produced wrong values and the contextual-type negative
  carried the spurious fallback warning.
- Icarus legacy focus: 5/5 passed (including one expected compile error).
- Icarus split-stream JSON focus: 5/5 passed.
- Adjacent positional/copy dynamic-array regressions: 18/18 passed.
- Adjacent assignment-pattern/associative-default regressions: 2/2 passed.
- Slang 11.0.448+e222e7dc0 differential, IEEE 1800-2017 mode: 22/22 exact
  accept/reject and diagnostic-count cases passed.
- Malformed VVP default-fill stack/receiver/width cases: 8/8 passed with exact
  diagnostics and no crash.
- Generated Caliptra-shaped VVP contains one `%fill/dar/obj/vec4` and no
  per-element `%set/dar/obj` expansion.

Commands used the worktree-local `local-install` compiler/runtime and the
native Python 3.13 tool environment. The campaign retains the 45-second CPU
guard but, per current direction, has no compiler RSS ceiling. The Apple
Silicon environment is assumed and is not repeatedly re-audited.

## Unmodified Caliptra replay

An assertion-enabled compile of the unmodified Caliptra integration testbench
was repeated after rebasing this change onto `0cc834736`. The former
`caliptra_top_tb_soc_bfm.sv:433` lone-default diagnostic is absent. Compilation
now reaches the next genuine Icarus gap at
`dma_transfer_randomizer.sv:79`: a bare dynamic-array `payload_data.size`
constraint is currently ignored even though the equivalent `size()` spelling
works. That constraint issue is not part of this constructor fix.

Elaboration then reports 52 mixed continuous/procedural driver errors in
`caliptra_top_tb_axi_complex.sv`. The implicated interface variables are
assigned by manager tasks and also driven by continuous assignments at the
subordinate endpoints. An exact reduced topology is rejected by both Icarus
and Slang 11. IEEE 1800-2023 clauses 6.5 and 10.3.2 prohibit a variable driven
by a continuous assignment from also receiving a procedural assignment, so
this is a Caliptra topology/tool-policy boundary rather than an Icarus feature
to make permissive.

The checked-in `Axi4PC.sv` is a sentinel for an unavailable proprietary ARM
checker. The replay supplied an inert file outside the Caliptra checkout; the
`AXI4PC` macro was not defined, so no checker instance was compiled. This run
therefore makes no proprietary-checker coverage claim. It was compile-only and
did not execute `jtagdpi`.

## Boundaries and memory note

This change closes the constructor-context lone-default form. It does not
claim standalone lone-default assignment semantics for a dynamic array or
queue, nor recursive scalar defaults into every field of a nonmatching nested
aggregate type.

A separate read-only audit found the previous full-Caliptra memory peak to be
bounded hierarchy-proportional elaboration: thousands of independently
instantiated assertion engines and a 257 MiB VVP image. There is some bounded
single-shot parse/elaboration retention, but no evidence of an unbounded
runtime leak. No memory-lifetime change is included here.
