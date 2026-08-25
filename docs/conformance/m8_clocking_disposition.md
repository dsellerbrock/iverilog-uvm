# M8 — Clocking blocks & program scheduling: clause-14 disposition matrix

Audit of IEEE 1800-2017 clause 14 (clocking blocks), exact modport access
under 25.5, and the program end-of-simulation interaction under 24.7. This is
the M8-5 deliverable: every listed clause-14 subfeature has a disposition, and
the implemented behaviors have permanent tests. The 2026-08-24 post-audit
focus, broad, VPI, negative, UVM, OpenTitan, and Caliptra reruns are complete;
the 2026-08-25 follow-up pins the public event of itemless clocking blocks.
Unsupported shapes in the table have a loud boundary rather than an ordinary-
assignment fallback.

Legend: ✅ verified & pinned · ⚠️ loud-`sorry` limitation (disclosed, not
silent) · — n/a.

| § | Subfeature | Disposition | Pinned by |
|---|-----------|-------------|-----------|
| 14.3 | `clocking cb @(event)` declaration | ✅ | sv_clocking_audit, skew_audit |
| 14.3 | `default clocking` | ✅ | sv_clocking_audit |
| 14.3 | `global clocking` | ✅ (parsed/selected) | sv_clocking_audit |
| 14.10 | Public clocking synchronization event, including itemless blocks | ✅ fires in Observed after NBA quiescence | sv_clocking_itemless_static_event, sv_clocking_itemless_program_event |
| 14.10 / 25.9 | Public event through plain and modport-qualified VIF handles | ✅, with no manufactured time-zero event | sv_clocking_itemless_vif_event, sv_clocking_vif_no_t0_event |
| 14.4 | `input` clockvar (default `#1step` Preponed sample) | ✅ | sv_clocking_audit |
| 14.4 | `input #N` skew (samples N units **before** the edge) | ✅, including static/VIF waiter ordering | sv_clocking_skew_audit, sv_clocking_vif_numeric_input_skew_delay_order |
| 14.4 | `input #0` skew (Observed-region sample) | ✅, including static/VIF waiter ordering | sv_clocking_vif_numeric_input_skew_zero_order |
| 14.4 | Output `#N` skew in the clocking block's defining timescale | ✅ for same-scope, static-instance, and VIF drives | sv_clocking_static_output_skew_scope, sv_vif_clocking_output_skew_scope |
| 14.4 | Nonconstant output skew | ✅ rejected once at the declaration, independent of drive count | sv_clocking_nonconstant_output_skew_fail |
| 14.5 | clockvar rename `input cv = sig` | ✅ | sv_clocking_audit |
| 14.5 | packed alias/member/select as the declaration-assignment target | ⚠️ selected target is rejected when hidden storage cannot represent it | sv_clocking_selected_decl_assign_target_fail |
| 14.11 | `output` clockvar edge-aligned drive | ✅ | sv_clocking_audit |
| 14.11 | `output #N` skew (drive applies N units **after** the edge) | ✅, including a drive issued after `@(cb)` | sv_clocking_skew_audit, sv_vif_clocking_output_skew_scope |
| 14.13 | Preponed sampling: packed integral clockvar | ✅ | sv_clocking_audit |
| 14.13 | Preponed sampling: packed struct clockvar | ✅ | sv_clocking_skew_audit |
| 14.13 | Non-vector clockvar (`real`/`string`) | ⚠️ `sorry` → alias (no sampling/skew) | probe |
| 14.13 | Unpacked-array clockvar | ⚠️ `sorry` → alias (no sampling/skew) | probe |
| 14.x | negedge / edge-qualified clocking event | ✅ | sv_clocking_audit |
| 14.x | Cycle delay `##N` (via default clocking) | ✅ | sv_clocking_audit |
| 14.13 | `@(cb)` and `@(vif.cb)` wake after numeric-skew samples are stored | ✅ | sv_clocking_vif_numeric_input_skew_zero_order, sv_clocking_vif_numeric_input_skew_delay_order |
| 14.16 | Constant bit/part/member output selection | ✅ for same-scope, static-instance, alias, and VIF spellings | sv_clocking_selected_output_static, sv_clocking_selected_output_alias, sv_vif_clocking_partial_select_preserve |
| 14.16 | Run-time-selected output drive | ⚠️ loud `sorry` pending once-only selector capture | sv_clocking_selected_output_dynamic_fail, sv_clocking_vif_selected_dynamic_fail |
| 14.16 | Clockvar in a concatenation/pattern l-value | ✅ rejected as illegal | sv_clocking_concat_member_lvalue_fail |
| 14.x | Clocking through a **virtual interface** (`vi.cb.sig`) | ✅, including a class-held VIF | sv_clocking_skew_audit, sv_clocking_class_vif_modport_output |
| 14.16 | Clocking-output drive through an indexed class receiver | ⚠️ loud `sorry` pending once-only receiver capture; root and nested indices take the same boundary | sv_clocking_indexed_class_receiver_fail, sv_clocking_root_indexed_class_receiver_fail |
| 14.x | Whole unpacked output clockvar buffering | ⚠️ loud `sorry`; no ordinary-NBA fallback | sv_clocking_unpacked_output_storage_fail |
| 14.3–14.5 / 25.5 | Exact modport visibility through direct and carried VIFs | ✅ retained through direct types, typedefs, arrays, class properties/type parameters, inheritance, and unpacked-struct members | sv_clocking_vif_modport_*, sv_clocking_class_vif_modport_*, sv_clocking_vif_modport_typedef_raw_member_fail, sv_clocking_class_typeparam_vif_modport_raw_member_fail, sv_clocking_struct_vif_modport_raw_member_fail |
| 14.13 / 25.5 / 36 | VIF clockvar/member passed to a VPI-backed system task/function | ✅ reads supported; every VPI property write is a loud run-time error and leaves the target unchanged | sv_clocking_vif_input_sys_task_arg, sv_clocking_vif_vpi_write_fail |
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

- **Public clocking synchronization event.** The block name denotes a public
  event in Observed whether or not the block declares any input or output
  items. Static, hierarchical, global, default-`##1`, VIF, and modport VIF
  references use that event rather than falling back to the raw Active-region
  edge. The internal sample/output trigger remains separate so existing
  buffering timing is unchanged. A two-state VIF event tick prevents its
  initialization from manufacturing an X-to-0 event at time zero. Synthesized
  samplers declared in a program run as design scheduler infrastructure and
  remain outside program-completion accounting.

- **Numeric input skew and clocking events.** Explicit `#0` inputs are
  sampled in Observed and become readable at the end of Observed processing.
  The compiler performs those phase-two stores before triggering the named
  clocking event or toggling the VIF tick, so both `@(cb)` spellings observe
  this edge's complete sampled values. Nonzero numeric skews use the same
  ordering guarantee after their delayed sample has matured.

- **Output selection and buffering.** The hidden output value and pending
  mask preserve constant packed bit, part, and member selections. Current-
  event same-scope, static-instance, and VIF drives wake the per-instance
  apply process, so one path owns the raw target and defining-scope output
  skew for both current-event and buffered drives. A run-time selector,
  indexed class receiver, unpacked output clockvar, or selected
  declaration-assignment target is rejected before the ordinary-NBA path;
  each requires a representation that captures its receiver/selector once.
  The indexed-receiver preflight includes an index on the root class-handle
  signal as well as one on a later class property, preventing the receiver
  expression from being cloned into multiple hidden accesses.

- **Modport provenance.** A modport-qualified virtual-interface type carries
  its selected view through typedefs, arrays, class properties, class type
  parameters, inheritance, unpacked-struct members, and generated
  clocking-state accesses. A raw member independently exported by the modport
  does not make an otherwise unexported clocking block visible. This enforces
  the exact source clocking-block name rather than validating only the
  rewritten raw property. The audit added negative reducers for every carrier
  that had previously erased this provenance.

- **VPI read/write boundary.** The property-aware VPI handle may read an
  integral or string virtual-interface property, which preserves read-only
  consumers such as `$sformatf`. A `vpi_put_value` targeting a VIF property is
  deliberately unsupported and reports `vvp error: writing a
  virtual-interface property through VPI is not supported; use an ordinary
  assignment or a clocking drive.` It sets a failing run status and leaves the
  target unchanged. This boundary covers a clocking input sample, a clocking
  output, and a plain modport input passed as an output argument to a
  VPI-backed call such as `$value$plusargs`; allowing the put would bypass
  14.13 sampling, 14.16 drive scheduling, or 25.5 direction enforcement.
  Ordinary SystemVerilog assignments and clocking drives still use their
  normal checked lowering.

- **Audit corrections.** The read-only audit found a root indexed receiver
  that was elaborated five times, output-skew metadata elaborated again for
  every source drive, modport qualifiers erased by typedef/type-parameter/
  structure carriers, VPI output arguments that mutated VIF state directly,
  and a partial l-value tree left allocated after nested modport rejection.
  The follow-up makes the indexed receiver loud, centralizes skew in the
  per-instance apply path with one declaration diagnostic, restores each
  modport carrier, makes VPI writes loud and read-only, and cleans the rejected
  l-value tree. Post-audit focused and broad reruns are clean.

## Post-audit evidence

These gates use the compiler and runtime rebuilt after the audit follow-up:

| Gate | Post-audit result |
|---|---|
| Clocking legacy + JSON/VVP focus | 36/36 in each harness |
| Clocking Slang differential | 59/59 |
| Complete SystemVerilog legacy manifest | 1850/1850 |
| Complete JSON/VVP manifest | 918/918 |
| Complete default legacy manifest | 4029 pass / 2 NI / 3 EF / 0 fail |
| VPI | 97/97 |
| Negative diagnostics | 111/111 |
| `make check` | pass |
| Real-DPI UVM | 338/338 |
| Fresh OpenTitan setup + compile | 7/7; six runtimes advance to the CPU guard, ADC retains its known zero-time testbench fatal |
| Caliptra Icarus/Slang differential | Icarus 53/105; Slang 54/105; zero `ICARUS_GAP` |

The OpenTitan row is a setup, compile, and bounded-progress result, not a clean
seven-test runtime claim. All seven compiles have zero hard errors. The six
long tests end at the deliberate 45-second CPU guard with advancing simulated
time and no compiler/runtime assertion; ADC reaches its already classified
testbench fatal at time zero.

## 2026-08-25 itemless public-event follow-up evidence

| Gate | Result |
|---|---|
| Itemless clocking legacy focus | 4/4 |
| Itemless clocking JSON/VVP focus | 4/4 |
| Complete default legacy manifest | 4051 pass / 2 NI / 3 EF / 0 fail (4056 total) |
| Complete JSON/VVP manifest | 941/941 |
| VPI | 108/108 |
| Negative diagnostics | 123/123 |
| `make check` | pass |
| Real-DPI UVM | 338/338 |
| Unchanged OpenTitan HMAC replay | former `is_idle()` mismatch cleared; next independent class-property event defect reached |

The HMAC replay is a bounded frontier result, not a clean test claim. The next
runtime change has its own red reducer and is kept out of this clocking batch.

The local standards reference consulted for the clause audit is the ignored
`docs/standards/local/IEEE_1800-2023.pdf`, SHA-256
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`.
The PDF is copyrighted, remains outside version control, and is not part of
this change; the conformance target remains IEEE 1800-2017.
