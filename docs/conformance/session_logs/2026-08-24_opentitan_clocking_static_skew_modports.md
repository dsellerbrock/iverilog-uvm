# OpenTitan clocking static-skew and exact-modport closure

Date: 2026-08-24

Baseline: `origin/main` at
`3d9afc7c6094fd382d4f118cfae5cb68b1505329`

Clocking implementation commits at audit start:

- `db6b1f7e3` — `Implement exact clocking skew and modport semantics`
- `2ae389d7a` — `Add clocking skew and modport regressions`

Worktree toolchain:

- compiler: `local-install/bin/iverilog`, native ARM64;
- runtime: `local-install/bin/vvp`, native ARM64;
- process wrapper: `../evidence/arm64-tooling/resource-runner`.

The relevant IEEE 1800-2017 boundaries are clocking declaration and signal
rules in 14.3–14.5, sampling in 14.13, clocking-output drives in 14.16, and
modport access in 25.5. The locally supplied IEEE 1800-2023 PDF was also
consulted from the intentionally ignored path
`docs/standards/local/IEEE_1800-2023.pdf`; its SHA-256 is
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`.
The copyrighted PDF is not tracked and is not part of this change. The
conformance target recorded here remains IEEE 1800-2017.

## Implemented clocking boundary before the audit

The clocking sampler stores default `#1step` inputs from Preponed history and
explicit numeric-skew inputs only after their delayed/Observed source is
ready. It triggers the named event and toggles the virtual-interface tick only
after every sample for that edge has been stored. Consequently, both `@(cb)`
and `@(vif.cb)` observe the complete sample set.

Output clockvars use one hidden value plus a bit-for-bit pending mask. Constant
packed member, bit, and part selections are retained through same-scope,
static-instance, alias, direct-VIF, and class-held-VIF spellings. The
per-instance apply process owns the raw destination and scales output skew in
the clocking block's defining timescale.

The following legal shapes remain deliberately loud because correct lowering
requires a persistent once-only capture or different storage model:

- a run-time-selected output drive;
- an output drive through a root or nested indexed class receiver;
- a whole unpacked output clockvar;
- a selected clocking declaration-assignment target that cannot be represented
  by whole hidden storage; and
- a non-default parameterized-interface width outside the existing shared
  interface-type model.

A clockvar is not a legal concatenation or assignment-pattern l-value under
14.16 and is rejected before any partial ordinary l-value tree can be built.

## Read-only correctness audit

The focused tests passed before the audit, but the audit found four semantic
holes and one ownership issue that the focus did not cover.

### Root indexed receiver was evaluated repeatedly

For `roots[choose()].vif.cb.raw <= 1'b1`, the original preflight inspected
indices only in the unresolved member tail. The root index is stored in the
resolved path head, so the compiler separately elaborated it for the output
buffer, pending mask, receiver/tick test, and kick accesses. The reducer
reported five calls to `choose()` for one source statement.

The follow-up treats an index on either the resolved root or any later class
property as the same loud once-capture boundary. It rejects the statement with
one `sorry` rather than cloning or executing the stateful selector.
`sv_clocking_root_indexed_class_receiver_fail` pins the root form; the existing
`sv_clocking_indexed_class_receiver_fail` pins the nested form.

### Output skew was elaborated per source drive

The apply process already owned the output skew, but the same skew expression
was elaborated again in each static current-event drive. A nonconstant skew
therefore multiplied diagnostics with the number of source drives.

Same-scope and static-instance current-event drives now set the hidden value
and pending mask and toggle the instance kick, just as the VIF path does. The
apply process is the only owner of raw-target resolution and skew elaboration.
Constant-expression failure suppresses the generic delay follow-up when the
constant elaborator already reported the source error.
`sv_clocking_nonconstant_output_skew_fail` requires one exact error even with
two drives.

### Modport provenance was erased by carrier types

The initial exact-view metadata covered a direct VIF and a direct class
property, but a typedef-backed module variable, a class type parameter, and an
unpacked-struct member could erase the qualifier. An unlisted raw interface
member, or an unexported clocking block whose raw member happened to be listed
independently, could then compile.

The follow-up retains both the selected modport and the original clocking-block
name through:

- direct and typedef-backed virtual-interface declarations;
- array wrappers;
- ordinary, inherited, and type-parameter-backed class properties;
- direct and typedef-backed unpacked-struct members; and
- compiler-generated sampled/buffered clocking properties.

Validation occurs at the exact interface hop. Listing a rewritten raw member
does not grant access to a clocking block absent from the modport's clocking
ports. The negative reducers are
`sv_clocking_vif_modport_typedef_raw_member_fail`,
`sv_clocking_class_typeparam_vif_modport_raw_member_fail`, and
`sv_clocking_struct_vif_modport_raw_member_fail`, in addition to the existing
direct/class-held collision and unexported-clock tests.

### VPI-backed output arguments bypassed language semantics

The property-aware handle is needed for read-only VPI-backed consumers of an
integral or string class/VIF property. Extending its put path to a bound
virtual interface was not sound: `$value$plusargs` could mutate a sampled
clocking input, write a clocking output immediately instead of through the
14.16 buffer/apply path, or write a 25.5 modport input.

The durable boundary is now:

- `vpi_get_value` on an integral or string VIF property is supported;
- `vpi_put_value` on an ordinary class property retains the existing support;
- `vpi_put_value` on any VIF property leaves the target unchanged, sets a
  failing run status, and emits:

  `vvp error: writing a virtual-interface property through VPI is not supported; use an ordinary assignment or a clocking drive.`

This is deliberately read-only/write-loud because the generic VPI put does not
carry enough source context to reproduce modport direction, clocking sampling,
or output scheduling. `sv_clocking_vif_input_sys_task_arg` keeps the read path
positive. `sv_clocking_vif_vpi_write_fail` checks sampled input, clocking
output, and modport input targets and requires all three values to remain
unchanged.

### Rejected nested modport l-value leaked a partial tree

Nested l-value validation can fail after the receiver/property chain and its
index expressions have been allocated. The audit found a direct return that
left that partial `NetAssign_` tree owned by nobody. The follow-up cleans the
partial tree on the validation error path. No use-after-free, double-free, or
other cast/lifetime defect was found in the virtual-output construction; its
RAII failure paths and cloned constant packed selections were otherwise sound.

## Retained pre-audit evidence

These results were complete before the correctness audit and are recorded
exactly as prior evidence. They are **not** post-audit verification:

| Gate | Result |
|---|---|
| Clocking legacy + JSON/VVP focus | 30/30 |
| Complete SystemVerilog legacy manifest | 1844 |
| Complete JSON/VVP manifest | 912 |
| Complete default legacy manifest | 4023 pass / 2 NI / 3 EF / 0 fail |
| VPI | 97 |
| Negative diagnostics | 111 |
| Real-DPI UVM | 338 |
| Fresh OpenTitan setup + compile | 7/7, with retained progress |
| Caliptra differential | Icarus 53/105 vs Slang 54/105; zero `ICARUS_GAP` |

The 30-case focus was run serially through the required wrapper:

```sh
cd ivtest
PATH="$PWD/../local-install/bin:$PATH" ../../evidence/arm64-tooling/resource-runner perl ./vvp_reg.pl regress-vif-clocking-output-focus-legacy.list
PATH="$PWD/../local-install/bin:$PATH" ../../evidence/arm64-tooling/resource-runner python3 ./vvp_reg.py regress-vif-clocking-output-focus-vvp.list
```

The OpenTitan result is a fresh setup-and-compile result plus retained
progress; it is not an OpenTitan pass claim. The Caliptra numbers
are the recorded Icarus/Slang comparison and do not turn either tool into the
definition of the standard.

## Post-audit verification

The compiler engine and runtime rebuilt from the audited tree are
`fdf07e553f4ae4f82aee56ea1d89d36c9add9771a543d85f031a47b925a2e266`
and
`4de1c635db1ed298a48d5a9bca12cd8b08cea43a5a502a0f26d1186a0c2db9c7`.
The installed copies match the build-tree binaries byte for byte.

| Gate | Post-audit result |
|---|---|
| Clocking legacy focus | 36/36 |
| Clocking JSON/VVP focus | 36/36 |
| Clocking Icarus/Slang reducer differential | 59/59 |
| Complete SystemVerilog legacy manifest | 1850/1850 |
| Complete JSON/VVP manifest | 918/918 |
| Complete default legacy manifest | 4029 pass / 2 NI / 3 EF / 0 fail |
| VPI | 97/97 |
| Exact negative diagnostics | 111/111 |
| `make check` | pass |
| Real-DPI UVM | 338 passed / 0 failed / 0 skipped |
| Fresh OpenTitan setup + compile | 7/7, zero hard compile errors |
| Caliptra differential | Icarus 53/105 in all three lanes vs Slang 54/105; zero `ICARUS_GAP` |

The expanded 36-case focus used the same serial wrapper commands shown above.
The six new reducers are red against the pre-audit compiler in the exact
legacy harness: 30/36 there versus 36/36 after the fix. The JSON focus is
36/36 after the fix; its expected-failure configuration verifies the VPI
case's nonzero status, while the legacy gold additionally pins its exact
diagnostic and unchanged values.

Fresh OpenTitan evidence is under
`evidence/opentitan-clocking-static-skew-post-audit-arm64-20260824/opentitan/fresh-build/`.
Darjeeling GPIO, DMA, MBX, UART, Earl Grey GPIO, and English Breakfast GPIO
all setup and compile successfully, then advance through simulated time until
the deliberate 45-second CPU guard. Their last time traces are respectively
7,197,976,140 ps, 3,228,042,157 ps, 1,056,020,595 ps, 1,490,164,502 ps,
7,146,068,568 ps, and 7,126,068,408 ps. ADC also setups and compiles, then
reaches its separately known zero-time UVM testbench fatal. This is 7/7
setup-and-compile plus bounded runtime progress, not a seven-test runtime-pass
claim. None of the seven shows the prior compiler abort or scheduler
assertion.

The frozen 105-target Caliptra replay completed 420 compiler invocations in
55.49 seconds wall time. Icarus remains 53/105 with assertions, 53/105 without
assertions, and 53/105 in synthesis; Slang remains 54/105. The sole raw lead is
`csrng_raw_wrap` source ordering, classified `SOURCE_ORDER_DEBT`, so the
matrix contains zero Icarus language gaps.
