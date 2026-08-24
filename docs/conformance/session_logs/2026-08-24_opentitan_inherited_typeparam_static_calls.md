# OpenTitan inherited type-parameter nested static calls

OpenTitan and Caliptra remained unmodified and read-only. This increment fixes
the factory-registration failure exposed after the DMA virtual-interface call
rows were repaired.

## Standards basis

IEEE 1800-2023 8.13 says that a derived class inherits the members of its base
class as if they were defined in the derived class. Clause 8.23 permits a type
parameter or typedef name on the left of `::`, permits access to protected
superclass elements from a derived class, and permits a class scope as the
prefix of a type or method call. Clause 8.25 defines type-parameterized class
specializations and explicitly permits a parameterized class to extend another
parameterized class.

The OpenTitan form is therefore legal:

```systemverilog
class alert_esc_agent extends dv_reactive_agent #(
  .DRIVER_T(dv_base_driver #(alert_esc_seq_item, alert_esc_agent_cfg))
);
  function void build_phase(uvm_phase phase);
    DRIVER_T::type_id::set_inst_override(
      alert_receiver_driver::get_type(), "driver", this);
  endfunction
endclass
```

`type_id` is the public typedef installed by the standard UVM component
registration macro.

## Defect and fix

`NetScope::find_typedef()` already followed the specialized superclass chain
and found inherited `DRIVER_T` and `MONITOR_T`. The scoped static-call
resolvers then tried to obtain each concrete type-parameter binding only from
the derived method's lexical parent and compilation-unit scopes. The bindings
belonged to the specialized `dv_reactive_agent` superclass scope, so both
statement and expression resolution returned no class. The SystemVerilog
compile-progress fallback then silently replaced all six factory override
calls with no-ops.

Both resolver paths now use `NetScope::find_typedef_scope()` to recover the
scope that owns an inherited type-parameter typedef before obtaining its
concrete binding:

- `resolve_scoped_class_type_name_task_()` for a static void-function call in
  statement position;
- `resolve_scoped_class_type_name_()` for a static value-function call in an
  expression.

This preserves existing lexical and typedef-shadowing rules because lookup
still selects the visible typedef first; only the already-selected typedef's
owning scope is used to fetch its bound parameter.

## Permanent regressions

`sv_inherited_typeparam_nested_static_call` models two UVM registry typedefs
reached through type parameters inherited by a nonparameterized derived class.
It value-checks static void-function calls, static value-function calls,
independent registry specializations, string and defaulted arguments, and the
concrete inherited bindings.

`sv_inherited_typeparam_nested_static_call_fail` proves that the recovered
call is not a permissive fallback: missing and extra arguments retain three
focused elaboration diagnostics. Slang 11.0.448 accepts the positive test and
rejects both negative calls under IEEE 1800-2017 and IEEE 1800-2023.

Before the compiler fix, the positive reducer emitted two `Enable of unknown
task ... ignored` warnings and failed at runtime because both registry writes
were absent.

## Unmodified OpenTitan witness

The frozen FuseSoC DMA closure was replayed from OpenTitan revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` in a clean worktree. Its generated
work directory is
`evidence/arm64-suite-timing-current-fixed-slice-20260824T0408MDT/opentitan/build/uvm/lowrisc_dv_dma_sim_0.1`.
It was compiled with the current ARM64 install and shared resource runner:

```sh
/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/resource-runner \
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-alert-driver-dispatch-fresh-arm64-20260824/local-install/bin/iverilog \
  -g2012 -stb -uvm \
  -DUVM -DUVM_NO_DEPRECATED \
  -DUVM_REG_ADDR_WIDTH=32 -DUVM_REG_DATA_WIDTH=32 \
  -DUVM_REG_BYTENABLE_WIDTH=4 -DSIMULATION -DDUT_HIER=tb.dut \
  -o dma.vvp -c matrix-iverilog.scr
```

The fully reproducible commands, transcripts, artifact hashes, source revision,
and work-directory provenance are retained in
`evidence/opentitan-dma-inherited-typeparam-arm64-20260824/SUMMARY.md`.

The final replay compiled in 2.94 seconds with exit zero. The six
`DRIVER_T/MONITOR_T::type_id::set_inst_override` warnings are gone. The image
constructs `dma_base_test`, no longer calls the deliberately fatal base
`dv_base_driver::get_and_drive()`, and advances from time zero to 4,201,386 ps.

That progress exposes the next independent runtime frontier: VVP aborts in an
any-edge event wakeup because an event wait-list thread is no longer marked as
waiting (`vthread_schedule_list`, with another observed run reaching the
duplicate `vthread_mark_scheduled` assertion). This scheduling bug is outside
the inherited type-parameter elaboration fix and is retained for the next
fresh-main increment. The DMA test is not yet claimed as passing.

## Invocation gotchas

- Build with Homebrew Bison 3.8.2 at
  `/opt/homebrew/opt/bison/bin/bison`. Apple's ARM64 `/usr/bin/bison` is
  version 2.3 and rejects this repository's grammar.
- Run `matrix-iverilog.scr` from its FuseSoC work directory because its source
  paths are relative.
- Use the native Python 3.13 OpenTitan environment and its logical venv Python
  path for FuseSoC and register generation. Resolving the interpreter symlink
  bypasses `pyvenv.cfg` and changes imports.
- The shared ARM64 resource runner keeps the 45-second CPU guard and imposes
  no RSS, address-space, data, file-size, compiler-image-size, or output-size
  ceiling.
- JSON compile-error tests normalize their source path to forward slashes.
  Native Windows accepts those paths, and Icarus therefore emits the same
  exact diagnostic text as Linux and macOS instead of backslash-only gold
  mismatches.
- A zero VVP exit status is insufficient for UVM classification. Inspect UVM
  fatal/error summaries and native runtime assertions.

## Validation

- OpenTitan nested-static focused regressions: 4/4 legacy and 4/4 JSON.
- Class-type focused regressions: 29/29 legacy and 18/18 JSON.
- Full legacy ivtest: 3,985 passed, 0 failed, 2 NI, and 3 expected failures
  across 3,990 cases.
- Full JSON/VVP ivtest: 874/874 passed.
- Negative regressions: 111/111 passed.
- Queue bytecode regressions: 3/3 passed.
- `make check`: passed.
- `make installuvm`: passed.
- Real-DPI UVM: 338/338 passed with no failures or skips.
- Slang 11.0.448: the positive reducer is accepted and the negative reducer
  reports both intended arity errors under IEEE 1800-2017 and IEEE 1800-2023.
