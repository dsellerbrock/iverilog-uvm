# `$system` function result and released PRINCE replay

The selected blocker is `OT-SYSTEM-FUNCTION-RETURN`. IEEE 1800-2017
§20.18.1 and IEEE 1800-2023 §20.17.1 specify that `$system` as a function
returns the C `system()` `int` result; without an argument it calls
`system(NULL)`, and the task form discards the result. Before this change,
`system_calltf` sent the shell status to VVP's process exit state and left
the SystemVerilog expression at its default zero. VVP also warned on the
standards-legal task form.

The private native arm64 tool was built from merged `main` at
`6014f8ebf664a6ecca84536c0d7fc2a30fa1ead4`, with this branch's two
source changes. Installed SHA-256 values: driver
`b205927bda2eb24261a6d74eb6e3c9c87d29d3ef6f92530c57c61002807af1e7`,
`ivl` `20df9f85fbea3da012ffe67b0dff167323a87c20d68f561914d69ceb34c06223`,
and VVP `c474a1e021795221d01ad1bc3c6f1a9c076f6996cc3254b265ad919b8cd21402`.
The pinned OpenTitan source is clean at
`a78922f14a8cc20c7ee569f322a04626f2ac6127`; it was not edited.

The permanent [reducer](../../ivtest/ivltests/sv_system_return.v) uses a
dynamic string argument, successful and nonzero-status commands, the
no-argument shell probe, and the task form. Before the patch,
`-g2017` and `-g2023` each compiled exit zero but VVP exited 1 at
`failed command returned success`; both emitted an inappropriate task-form
warning. With the patched private VVP, both print only `PASSED` and exit zero.
The final fixture's [legacy](focus-legacy.log) and [JSON](focus-json.log)
registrations each pass 2/2, and the adjacent chapter-20 JSON focus passes
7/7. The full `.github/ivtest_gate.sh` passes: legacy 6,680 total with
6,675 ordinary passes, zero failures, two not implemented, and three
expected failures; bundled VPI 131/131, negative 155/155, and runtime
invariants 15/15. A test-only portability adjustment was made during that
broad run; the final fixture was rerun in both focused harnesses afterward.
The full JSON suite is deferred to the approximately ten-fix integration
checkpoint; the paired and adjacent JSON focus above ran on the final image.
The [real-DPI UVM gate](real-dpi-uvm.log) also completed with 358/358 passed,
zero failed or skipped, and the REAL DPI umbrella loaded.
The separate
[extra-argument RED](system_extra_arg_fail.v) compiles in both editions;
its arity defect is parked as `DD-062`, outside this blocker.

The exact pinned `lowrisc:dv:prim_prince_sim:0.1` one-core runner compiles
with **`-gcommercial-unsafe`**. Its first patched runtime moved past the
false `dv.stop` fatal but failed because the required PRINCE DPI symbol was
not loaded ([result](prince-missing-dpi.json)). We built the generated
`crypto_dpi_prince.c` plus `matrix-runtime.dpiexport.c` into a native arm64
DPI bundle (SHA-256
`b4dab40815958f5faa58c4f8546fd2f7082fafe56498e0c02c79e041db4da0cb`)
and replayed the same smoke with `vvp -d` ([full runner result](prince-with-dpi.json),
[setup](prince-setup.log), [compile](prince-compile.log),
[runtime](prince-runtime.log)). The compile exited zero with zero hard errors
and zero compiler semantic-debt diagnostics. Runtime completed in 11.378 s,
exited zero, reported one `TEST PASSED CHECKS`, zero fail markers, and zero
runtime errors or assertions. The unchanged testbench runs five golden and
one random vector under `+smoke_test=1`, compares both encryption and
decryption against the native reference across its variants, and prints
`All encryption and decryption passes were successful!` only after those
checks. The final `$finish` is at 2,624,180 ps.

| PRINCE profile | Runner status | First runtime outcome |
| --- | --- | --- |
| Merged 84-row unsafe baseline | `RUNTIME_FAIL` | False `dv.stop` fatal before vectors |
| Patched, no native DPI | `RUNTIME_FAIL` | Reaches vectors; required DPI symbols missing |
| Patched, native DPI loaded | `DEBT` | Six checked vectors complete, zero runtime errors |

This is **1/1 named checked nonstandard compatibility PRINCE replay**, not
an IEEE conformance result. The matrix row remains `DEBT` because FuseSoC
setup emits two unknown Root mapping warnings and one native C-source
mapping warning tracked by the runner; the raw setup log also contains a
backend-deprecation warning. The merged 84-row unsafe baseline and its conservative
**0/49 clean runtime matrix rate are unchanged**; this single named replay
is reported separately.

To repeat from this worktree with the pinned OpenTitan Python 3.13/FuseSoC
environment, use the setup/compile/runtime commands in
`prince-with-dpi.json`. The sequence is a one-core
`scripts/opentitan_matrix.py --lane runtime
--core lowrisc:dv:prim_prince_sim:0.1 --commercial-unsafe` compile, then
the following native bundle build from its generated job directory:

```sh
cd /private/tmp/ot-system-return-prince-20260925/work/runtime/lowrisc_dv_prim_prince_sim_0.1
cc -std=c99 -O2 -fPIC -dynamiclib -undefined dynamic_lookup \
  -I/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-system-return-20260925 \
  -Isrc/lowrisc_dv_crypto_prince_ref_0.1 \
  src/lowrisc_dv_crypto_dpi_prince_0.1/crypto_dpi_prince.c \
  matrix-runtime.dpiexport.c -o prince_dpi.dylib
```

Repeat the one-core runner with the bundle loaded (for the initial compile,
omit the `--dpi-library` option):

```sh
TREE=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-system-return-20260925
TOOL_PY=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python
cd "$TREE"
PATH="/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin:$TREE/local-install/bin:$PATH" \
  "$TOOL_PY" scripts/opentitan_matrix.py \
  --opentitan-root /Users/danielellerbrock/projects/iverilog_uvm/clean-corpora/opentitan-7a3ad34 \
  --build-root /private/tmp/ot-system-return-prince-20260925/work \
  --result-json /private/tmp/ot-system-return-prince-20260925/with-dpi.json \
  --result-md /private/tmp/ot-system-return-prince-20260925/with-dpi.md \
  --iverilog local-install/bin/iverilog \
  --uvm-home /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src \
  --fusesoc /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/fusesoc \
  --fusesoc-python "$TOOL_PY" --lane runtime \
  --core lowrisc:dv:prim_prince_sim:0.1 --commercial-unsafe \
  --dpi-library /private/tmp/ot-system-return-prince-20260925/work/runtime/lowrisc_dv_prim_prince_sim_0.1/prince_dpi.dylib \
  --jobs 1 --setup-timeout 120 --compile-timeout 120 --runtime-timeout 120
```

The runner retains
`+cdc_instrumentation_enabled=1 +smoke_test=1`; no testbench check or
application source was changed.
