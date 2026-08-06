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

### C1 — `pkg::type` in module port declarations — **CLOSED (false alarm)**

Parser handles `pkg::type` in ports. Errors were from compilation ordering.

### C2 — Caliptra build system — **infrastructure gap**

Caliptra uses Verilator + RISC-V GCC, not FuseSoC.

**Synthesis census (2026-08-06, deep): 464 RTL files, ZERO compiler bugs.**
All errors are alphabetical compilation ordering:
- `aes.sv` before `aes_pkg.sv` — same-directory ordering
- `doe_defines_pkg` imports `kv_defines_pkg` — cross-directory ordering
- `lc_ctrl_pkg` imports `lc_ctrl_state_pkg` — same-directory ordering
- `kmac_pkg` references `ot_sha3_pkg` — same-directory ordering
- One `include` path issue (caliptra_sva.svh in libs/rtl)

**SVA status**:
- `caliptra_top_sva.sv`: Depends on generated register packages (keymgr_pkg,
  axi_dma_reg_pkg) — needs full build env, not a compiler gap
- `kv_boot_flow_sva.sv`: 2 package ordering gaps, trivially resolved
- Formal properties (fv_sha512_pkg.sv): Assignment pattern `'{...}` in
  parameter value may not be fully supported

### C3 — UVM: SHA512 compiles with UVMF stubs — **working (2026-08-06)**

**Full SHA512 UVM environment compiles with ZERO errors** using minimal
UVMF stub packages (2 files, ~80 lines total).

Compilation manifest:
1. `uvm-core/src/uvm_pkg.sv` (bundled with iverilog-uvm)
2. UVMF stubs: `uvmf_base_pkg.sv`, `uvmf_base_pkg_hdl.sv` (in /tmp/uvmf_stub)
3. RTL package deps: `caliptra_prim_util_pkg`, `kv_defines_pkg`, `pv_defines_pkg`
4. SHA512 UVM: `SHA512_in_pkg_hdl`, `SHA512_in_pkg`, `SHA512_out_pkg_hdl`,
   `SHA512_out_pkg`, interface files, BFM files, `SHA512_env_pkg`

Remaining (build-system, not compiler):
- 4 "Invalid module instantiation" errors in BFMs — need DUT modules
- `hdl_top.sv` needs full test harness (SHA512 DUT + all dependencies)
- Other IP UVM envs (hmac, ecc, keyvault, pcrvault, soc_ifc, integration)
  should follow same pattern

### C4 — UVMF stub packages created — **delivered**

Two stub files at `/tmp/uvmf_stub/`:
- `uvmf_base_pkg.sv`: UVM-side base classes (transaction, sequence,
  driver, monitor, env, agent, test, scoreboard, config bases)
- `uvmf_base_pkg_hdl.sv`: HDL-side typedefs (active_passive,
  initiator_responder enums)
