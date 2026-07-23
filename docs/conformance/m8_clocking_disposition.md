# M8 — Clocking blocks & program scheduling: clause-14 disposition matrix

Audit of IEEE 1800-2017 clause 14 (clocking blocks) and the program
end-of-simulation interaction (24.7). This is the M8-5 deliverable: every
clause-14 subfeature has a disposition, and the verified behaviors are
pinned by machine-checked tests. **No disposition below is a silent
miscompile — every unsupported shape is a loud `sorry`.**

Legend: ✅ verified & pinned · ⚠️ loud-`sorry` limitation (disclosed, not
silent) · — n/a.

| § | Subfeature | Disposition | Pinned by |
|---|-----------|-------------|-----------|
| 14.3 | `clocking cb @(event)` declaration | ✅ | sv_clocking_audit, skew_audit |
| 14.3 | `default clocking` | ✅ | sv_clocking_audit |
| 14.3 | `global clocking` | ✅ (parsed/selected) | sv_clocking_audit |
| 14.4 | `input` clockvar (default `#1step` Preponed sample) | ✅ | sv_clocking_audit |
| 14.4 | `input #N` skew (samples N units **before** the edge) | ✅ | sv_clocking_skew_audit |
| 14.4 | `input #0` skew (Observed-region sample) | ✅ compiles | sv_clocking_skew_audit (compile) |
| 14.5 | clockvar rename `input cv = sig` | ✅ | sv_clocking_audit |
| 14.11 | `output` clockvar edge-aligned drive | ✅ | sv_clocking_audit |
| 14.11 | `output #N` skew (drive applies N units **after** the edge) | ✅ | sv_clocking_skew_audit |
| 14.13 | Preponed sampling: packed integral clockvar | ✅ | sv_clocking_audit |
| 14.13 | Preponed sampling: packed struct clockvar | ✅ | sv_clocking_skew_audit |
| 14.13 | Non-vector clockvar (`real`/`string`) | ⚠️ `sorry` → alias (no sampling/skew) | probe |
| 14.13 | Unpacked-array clockvar | ⚠️ `sorry` → alias (no sampling/skew) | probe |
| 14.x | negedge / edge-qualified clocking event | ✅ | sv_clocking_audit |
| 14.x | Cycle delay `##N` (via default clocking) | ✅ | sv_clocking_audit |
| 14.x | Clocking through a **virtual interface** (`vi.cb.sig`) | ✅ | sv_clocking_skew_audit |
| 14.x | Clocking through a **parameterized** virtual interface | ⚠️ one-time `warning` — specialization not modeled (see repros/param_vif_member_write_truncation.sv) | M8-3 note |
| 24.7 | Program whose only tail activity is a clocking block still ends the sim | ✅ (was a hang; fixed) | sv_program_clocking_finish |

## Notes

- **Non-vector / unpacked-array clockvars (14.13).** The synthesized
  Preponed sampler is built for vector-valued signals. A `real`, `string`,
  or unpacked-array clockvar cannot go through it, so the clockvar is a
  direct **alias** to the source signal and reads its *current* (unsampled)
  value. This is announced with a loud `sorry ... keeps the alias
  behavior`, so a testbench that mutates such a signal between edges is
  warned rather than silently miscompiled. Proper non-vector sampling is
  future work; it is not a silent gap.

- **Parameterized virtual-interface clocking (M8-3).** A `#(N)` override on
  a virtual-interface type is not yet modeled (the netclass is shared
  per-interface-module with default parameters). Clocking access through a
  *non-parameterized* vif is verified (`sv_clocking_skew_audit`); the
  parameterized case emits a one-time loud warning and is tracked with a
  repro. Not a silent miscompile.

- **Region ordering (M8-4).** The Preponed input sample, the Observed
  assertion evaluation, and the Re-NBA output drive are ordered by the
  synthesized sampler/apply processes; the program end-of-simulation count
  excludes the clocking sampler and output-apply processes (24.7), which
  fixed a hang where a program whose only tail activity was a clocking
  block never ended. Pinned by `sv_program_clocking_finish`.
