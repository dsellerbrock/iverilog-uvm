# Caliptra gap ledger

One row per distinct defect found while making the iverilog-uvm fork run
[Caliptra](https://github.com/chipsalliance/caliptra-rtl). 

## Status: Initial compilation census (2026-08-06)

The Caliptra RTL tree contains 732 SystemVerilog files across 30+ IP blocks
(aes, sha256, sha512, sha3, kmac, hmac, ecc, mldsa, keyvault, pcrvault,
datavault, csrng, edn, entropy_src, entropy_combiner, hmac_drbg, doe,
lc_ctrl, abr, riscv_core, soc_ifc, spi_host, uart, axi, ahb_lite_bus,
caliptra_prim, caliptra_prim_generic, caliptra_tlul, libs, integration).

Caliptra shares many primitive libraries with OpenTitan (the `caliptra_prim`
and `caliptra_prim_generic` packages are forked from OpenTitan's `prim` and
`prim_generic`). All OpenTitan conformance fixes (G1 through G40) therefore
apply to the Caliptra shared primitives as well.

The initial census strategy: compile each IP block individually with its
dependencies, catalog the errors, and classify them as:
- Already-fixed (OpenTitan fixes carry over)
- New parser gap
- New synthesis gap 
- Include/build-system gap

## Known applied fixes (carried from OpenTitan campaign)

| Gap | Description | Caliptra Status |
|-----|-------------|-----------------|
| G1 | Parenthesized property syntax | ✅ Applies |
| G2 | Property starting with `(` as boolean expression | ✅ Applies |
| G3 | Conditional enum type | ✅ Applies |
| G4 | Size cast of string literal | ✅ Applies |
| G5 | Continuous assign to packed-array struct member | ✅ Applies |
| G6 | For-loop with multiple typed declarations | ✅ Applies |
| G7 | Unbounded consecutive repetition | ✅ Applies |
| G8 | s_eventually as implication consequent | ✅ Applies |
| G9 | Run-time index in non-final packed dimension | ✅ Applies |
| G10 | Variable-length implication antecedents | ✅ Applies |
| G11-G12 | Sequence combinators as implication operand | Partial |
| G13 | Non-literal cycle-delay bounds | ✅ Applies |
| G14-G15 | Multi-dim packed parameter selects | ✅ Applies |
| G16 | Variable index into struct-member packed array | Partial |
| G17 | Multiple-driver analysis | ✅ Applies |
| G18-G24 | Synthesis fixes | ✅ Applies |
| G25 | Per-bit latch enables | ✅ Applies |
| G26-G39 | Synthesis improvements | ✅ Applies |
| G40 | Shared-state nested loop propagation | ✅ Applies |

## New Caliptra-specific gaps

*To be populated after compilation census.*
