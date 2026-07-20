# DPI export — design (Phase 3 big-rock item)

`export "DPI-C" function f;` / `export "DPI-C" task t;` (IEEE 1800-2017
35.5) makes a SystemVerilog subroutine callable from C. It is the last
DPI item and one of the deepest remaining features: unlike everything in
the M9-NFA arc and `expect` (all frontend `parse.y`/`pform.cc` source
transforms), export spans FOUR layers — the `ivl_target` ABI,
elaboration, the vvp code generator, and the vvp runtime — plus a
scope-context (`svScope`) mechanism that does not exist yet. This file is
the plan; per the project's big-rock methodology (see
`m6_callf_rearchitecture.md`, `m9_nfa_design_2026-07-19.md`) the design
lands before the code, staged into regression-clean increments.

## 1. Current state (honest)

`export "DPI-C"` is a LOUD sorry at the grammar (`parse.y` ~4917): the
declaration is dropped with *"export \"DPI-C\" … is not yet supported;
calls from C to '<name>' will not link."* The C side then fails to
resolve the symbol at first call (`vvp` link error). No silent
miscompile. The sorry is deliberately SOFT (it does not increment
`error_count`), so a UVM testbench that DECLARES an export it never
exercises still compiles — making it a hard error would regress those.
Any implementation must preserve that "declared-but-unused is fine"
property.

## 2. Why it is hard: the symbol-resolution problem

`vvp` loads DPI libraries with `dlopen(RTLD_LAZY|RTLD_GLOBAL)`
(`ivl_dlfcn.h`). So:

- the library's `extern void sv_wait(void);` reference is resolved on the
  FIRST CALL (lazy), against the global symbol namespace, which includes
  `vvp`'s own exported symbols;
- but `vvp` is a prebuilt binary: it cannot contain a symbol named
  `sv_wait` (an arbitrary user `c_identifier`) chosen at compile time.

Therefore the exported C symbol must be provided by GENERATED C: for each
exported subroutine the tool emits a tiny stub

```c
    /* generated */
    void sv_wait(void) { __ivl_dpi_export_call_void("<scope>", "sv_wait"); }
    int  sv_add(int a, int b) {
          return __ivl_dpi_export_call_i("<scope>", "sv_add", 2, a, b);
    }
```

compiled into (or alongside) the user's DPI object, where
`__ivl_dpi_export_call_*` is a generic dispatcher exported by `vvp`
(resolved via `RTLD_GLOBAL`). This is the standard commercial-tool
pattern (a generated export header/stub); iverilog historically lacked it,
which is why export is unsupported. The stub generation is a first-class
part of the feature, not an afterthought.

## 3. The scope-context (`svScope`) gap

35.5.2: an exported subroutine runs in a specific SV instance. C selects
it with `svGetScope`/`svSetScope`, and an imported `context` function's
scope is the default. `vvp` has NO `svScope` today. Export needs:

- `svScope svGetScope(void)` — the scope of the DPI import currently on
  the C stack (a per-thread "active DPI scope" set when `%dpi/call`
  enters a `context` import);
- `svScope svSetScope(svScope)` / `svGetNameFromScope` / `svGetScopeFromName`;
- the dispatcher resolves `<scope>` + the SV name to the function's
  compiled thread definition (`TD_<mangled>`).

For a single-instance static export the scope is unambiguous; the general
(multi-instance / automatic) case needs the full `svScope` plumbing.

## 4. Running the SV subroutine from C (re-entrancy)

The dispatcher is called from C that is itself running inside a
`%dpi/call` opcode — i.e. `vvp` is suspended mid-opcode on some thread.
To run the exported subroutine it must, synchronously and in zero time
(for a function):

1. locate `TD_<scope-of-export>` and allocate a child `vthread` at its
   entry (`vthread_new`);
2. marshal the C arguments into the subroutine's argument nets/vars
   (the reverse of the import marshaling in `vvp_dpi.cc`);
3. drive that thread to completion WITHOUT yielding the active region —
   exactly the atomicity guarantee the **M6-CALLF trampoline** already
   provides for SV→SV calls. The dispatcher reuses that inline-frame
   machinery, entered from C instead of from a `%callf` opcode;
4. read the return net and marshal it back to C.

A time-consuming exported TASK (it calls `#delay`) additionally needs the
C stack suspended across simulation time — the hardest sub-item, deferred
to the end of the arc (it is the same C-stack-suspension problem the
closure plan calls the "C-symbol trampoline").

## 5. Incremental plan (each a regression-clean checkpoint)

1. **ivl_target ABI + elaboration.** Add an export registry: elaboration
   records `(scope, sv_name, c_name)` for each `export "DPI-C"`; expose it
   via `ivl_design_*`/`ivl_scope_*` accessors. Grammar stops sorrying and
   stores the export instead. No behavior change yet (codegen still
   diagnoses at the point of use), so gates stay clean.
2. **C-stub codegen.** `tgt-vvp` emits a companion `<out>.dpiexport.c`
   with one stub per export calling `__ivl_dpi_export_call_*`, and a vvp
   name→`TD_` table. Document the compile step (the stub is compiled into
   the DPI object).
3. **Runtime dispatcher — zero-time functions, single static scope.**
   `__ivl_dpi_export_call_*` in `vvp`: marshal, run `TD_` via the
   M6-CALLF trampoline entered from C, marshal the result back. Scope is
   the single static instance (svScope not yet required). End-to-end test:
   C calls an exported `int f(int)` and gets the SV result.
4. **`svScope` plumbing.** `svGetScope`/`svSetScope` + per-thread active
   DPI scope; multi-instance and `context`-relative export.
5. **Time-consuming task export.** C-stack suspension across time for an
   exported task that consumes `#delay`, building on (3)+(4).

Invariants at every step: the four standing gates stay clean; a
declared-but-unused export still compiles; anything not yet lowered is a
loud sorry, never a silent miscompile.

## 5a. Implementation status (2026-07-20)

Steps 1–3 are **implemented and end-to-end verified**: C can call an
exported SV function/task and get the correct result.

- **Frontend.** `export "DPI-C" [c=]{function|task} name;` no longer
  sorries at the grammar; `pform_set_dpi_export` (pform.cc) looks the
  subroutine up in the enclosing scope and marks it. The export must
  *follow* its definition in the same scope (forward/out-of-scope export
  is a loud sorry — not yet supported).
- **ABI.** `PTaskFunc::is_dpi_export()/dpi_export_c_name()` flow through
  `t-dll.cc` to `ivl_scope_is_dpi_export()/ivl_scope_dpi_export_c_name()`.
- **Codegen.** `tgt-vvp` collects exported scopes and emits, after all
  scopes, a `:export_dpi "cname" "TD_label" "retsig" "argsig" "" "argnets"`
  runtime directive plus a companion `<out>.dpiexport.c` C stub. The stub
  packs its C arguments into an `ivl_dpi_arg_t[]` and calls the vvp
  dispatcher `__ivl_dpi_export_call_{i,r,v}`. The user compiles the stub
  into their DPI object.
- **Runtime.** `compile_export_dpi` (compile.cc) registers each export,
  resolving the argument nets to `vvp_net_t*` at link time (the VPI symbol
  table is freed afterwards). The dispatcher (`dpi_export_run_` in
  vthread.cc) — entered from C during a `%dpi/call` — resolves the `TD_`
  entry via the persistent `runtime_code_scope_map`, marshals the C args
  into the argument nets, runs the subroutine synchronously as an
  M6-CALLF-style inline child of `running_thread`, and reads the return
  off the caller stack (the `%ret` protocol) — never a return net, since a
  function has none.

Supported: zero-time functions and tasks, single static instance,
arguments and return being integer atoms (byte/shortint/int/longint,
signed or unsigned) or real, and void. Everything else is a **loud sorry**
that drops the export (the C symbol is not generated, so a call from C
fails to link with a diagnostic) — never a silent miscompile. A
declared-but-unused export still compiles cleanly.

Follow-up (2026-07-20, UVM DPI enablement): export resolution was made
order-independent (an export may precede its definition — UVM's
`m__uvm_report_dpi` does), and **string** arguments/return are now
marshaled. Together with a fork-owned Icarus UVM DPI backend
(`uvm_dpi/uvm_dpi_iverilog.cc`: vendored regex/command-line/common + an
`uvm_hdl_*` VPI backdoor) and the `svScope` API (H.9), this lets the UVM
regression run WITHOUT `UVM_NO_DPI` (200/200 green). The four standing
gates stay clean.

Still open (steps 4–5): `svScope` MULTI-instance and `context`-relative
export (the single-static-scope and package-scope cases work);
time-consuming task export (C-stack suspension across simulation time) — a
time-consuming exported subroutine is a loud runtime sorry. Object /
open-array / wide-vector and output/inout arguments in exports remain loud
sorries pending further marshaling work.

## 6. Test strategy

- Positive: a `tests/` DPI pair (`*.sv` + `*.c`) exercising an exported
  function called from an imported `context` function, self-checking on
  the returned value (the `uvm_test.sh` harness already compiles `.c`
  companions with `gcc -shared -fPIC` and runs `vvp -d`).
- Negative: shapes not yet supported (time-consuming export before step 5,
  unsupported signatures) remain loud sorries with `tests/negative`
  coverage.
