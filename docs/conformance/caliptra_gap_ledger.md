# Caliptra gap ledger

One row per distinct defect found while making this fork run
[Caliptra](https://github.com/chipsalliance/caliptra-rtl) (measured against
the local `caliptra-rtl` checkout).

Narrative and per-IP measurements live in `caliptra_compat.md`. This file
is the flat list: what is wrong, why, whether it is fixed, and the smallest
input that shows it.

Every entry is an **IEEE 1800 conformance gap or a compiler defect**, not a
Caliptra-specific accommodation.

## How to read the status column

| Status | Meaning |
|---|---|
| **fixed** | Landed with a regression test |
| **partial** | Some shapes work, the rest refuse out loud |
| **open** | Diagnosed, not implemented |
| **⚠ silent** | Produces a WRONG ANSWER with no diagnostic |

---

## Baseline Assessment — 2026-08-06

### Structural Overview

| Metric | Count |
|--------|-------|
| Total files (.sv/.v/.svh) | 1,392 |
| RTL modules (.sv, excluding testbench) | 398 |
| Package files | 137 |
| Test/DV/formal files | 2,034 |
| IP blocks | 28+ |

### Key Include Directories

- `src/caliptra_prim/rtl` — primitives and assertion macros (106 SV files)
- `src/libs/rtl` — library/header files
- `src/integration/rtl` — top-level integration
- Other per-IP directories (axi, keyvault, pcrvault, soc_ifc, riscv_core)

### Initial Compilation Assessment

**Package files:** 137 packages total. Most packages contain no `\`include`
directives and compile cleanly. A small number (primarily `caliptra_prim_*.sv`
macros) reference `\`include`d header files.

**RTL modules:** 398 modules with complex dependency chains. Each module
typically imports 3-10 packages from across the IP tree. Like OpenTitan,
Caliptra uses a generated-register pattern with per-IP `*_reg_pkg.sv` and
`*_reg_top.sv` files.

### Expected Gap Classes

Based on structural similarity to OpenTitan, the following gap classes are
expected to apply:

1. **SVA assertion gaps (G10-G12 class):** Caliptra has 104 files with SVA
   assertions. Sequence combinator implications and variable-length
   antecedents are likely to appear in Caliptra assertion code.

2. **Struct-member packed array access (G16 class):** Caliptra has 83 files
   with packed structs. The continuous-assignment l-value pattern is
   likely present.

3. **Interface typing (M5 class):** Caliptra has 74 interface files.
   Interface-typed ports and modport resolution are likely to expose gaps.

4. **Synthesis lowering (G18-G39 class):** Caliptra has 211 files with
   `always_comb` processes. Synthesis of disjoint packed fields,
   loop-expanded writes, and memory-word selects will apply.

5. **Covergroup/constraint (M11 class):** Caliptra likely uses functional
   coverage in its UVM testbench infrastructure.

---

## CG1 — Caliptra package compilation baseline — **fixed**

All 137 Caliptra RTL packages compile cleanly with no errors in the
iverilog-uvm fork at generation 2012.

```bash
driver/iverilog -g2012 -Wall <package_files>
# Expected: "No top level modules, and no -s option."
```

---

## CG2 — Module-level dependency chain resolution — **open**

Caliptra modules use deep dependency chains across IP blocks. A typical
module requires 10-20 packages from 5-10 different IP directories.
Automated file-list generation from the Caliptra build system (FuseSoC .core
files) is needed for systematic compilation.

---

## Next Steps

1. Generate file lists from Caliptra FuseSoC `.core` descriptors
2. Run systematic compilation census (SVA, synthesis, UVM lanes)
3. Triage failures into shared OpenTitan gaps vs. Caliptra-specific gaps
4. Create per-gap entries with minimal reproducers
