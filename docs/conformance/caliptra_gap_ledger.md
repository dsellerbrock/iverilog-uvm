# Caliptra gap ledger

One row per distinct defect found while making the iverilog-uvm fork run
[Caliptra](https://github.com/chipsalliance/caliptra-rtl).

## UVM Assessment (2026-08-06)

**Caliptra has a massive UVM presence: 741 files across 7 IP blocks plus the
integration top (caliptra_top).** The UVM infrastructure includes:

| IP | UVM Files | UVM Components |
|----|-----------|----------------|
| sha512 | 56 | env, in/out_if, sequences, scoreboard |
| hmac | 62 | env, in/out_if, sequences, scoreboard |
| keyvault | 115 | env, if packages, sequences, tests |
| pcrvault | 96 | env, if packages, sequences, tests |
| soc_ifc | 307 | env, if packages, sequences, tests, coverage |
| ecc | 60 | env, if packages, sequences |
| integration | 26 | caliptra_top env, sequences |
| libs/uvmf | 19 | shared UVM Framework infrastructure |

**Total**: 741 SV/SVH files, 295 sequence files, 29 scoreboards, 19 interface packages.

### UVM compilation status

✅ **Minimal UVM test compiles and runs** on iverilog-uvm (compile-progress
warnings only, expected for the iverilog UVM fork).

⛔ **Caliptra UVM environments depend on external libraries** not in the tree:
- `uvmf_base_pkg` / `uvmf_base_pkg_hdl` — UVM Framework base packages
  (referenced as `${UVMF_HOME}/uvmf_base_pkg` in filelists)
- Questa MVC AHB VIP (`${QUESTA_MVC_HOME}`) — Mentor-specific, won't work
  with iverilog

### What's needed to make Caliptra UVM work on iverilog

1. **C1 (blocker)**: `pkg::type` in module port declarations (65+ files)
2. **UVMF dependency**: Either clone the UVM Framework repository or create
   stub packages that satisfy the UVMF base package imports
3. **Questa MVC replacement**: Replace Mentor AHB VIP with a simple
   behavioral AHB model or stub
4. **Filelist-based compilation**: Create iverilog-compatible filelists
   that resolve all dependencies

---

## Initial compilation census (2026-08-06)

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

### C1 — `pkg::type` in module port declarations — **open**

*23.2.1 / A.1.3 [Caliptra-specific] — 65+ files affected.*

Caliptra uses package-qualified type references in module port declarations:

```systemverilog
module aes (
  output caliptra_prim_mubi_pkg::mubi4_t  idle_o,
  input  lc_ctrl_pkg::lc_tx_t            lc_escalate_en_i,
  input  entropy_src_pkg::cs_aes_halt_req_t cs_aes_halt_i
);
```

iverilog currently rejects `pkg::type` syntax in port declarations with
`syntax error` / `Errors in port declarations`. The type reference is
in a different syntactic position than ordinary `pkg::type` in variable
declarations; the parser's port production (`parse.y`) does not accept
a package-scoped type in the `list_of_port_declarations` rule.

**Scope:** Used pervasively in Caliptra's generated register interfaces
(`*_reg.sv`, `*_reg_top.sv`) and in crypto core wrappers (aes, csrng,
hmac, sha512, sha256, kmac, keyvault, pcrvault, datavault, ecc, mldsa,
doe, entropy_src, soc_ifc).

**Fix path:** Extend `parse.y` port declaration rules to accept
`package_scope::identifier` as a valid type in port lists.

### C2 — Caliptra build system — **infrastructure gap**

Caliptra uses Verilator + RISC-V GCC for simulation, not FuseSoC.
CI: `.github/workflows/build-test-verilator.yml` with Verilator v5.044.

To integrate iverilog with Caliptra RTL:
1. Fix C1 (pkg::type in ports)
2. Generate register packages with `reg_gen.py` (already in tree)
3. Create a FuseSoC `.core` wrapper or a simple Makefile-based flow
4. Handle Caliptra-specific primitives (caliptra_prim_generic, etc.)

### C3 — UVM dependency on external UVM Framework — **infrastructure gap**

Caliptra UVM environments depend on:
- `uvmf_base_pkg` — UVM Framework base package (external, `${UVMF_HOME}`)
- Questa MVC AHB VIP — Mentor-specific (external, `${QUESTA_MVC_HOME}`)

To run Caliptra UVM on iverilog:
1. Clone/integrate the UVM Framework repository
2. Replace Questa MVC AHB VIP with a behavioral model or stub
3. Create iverilog-compatible filelists
