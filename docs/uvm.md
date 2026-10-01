# Running UVM on this fork

Use the [README quick start](../README.md#run-uvm) to build the toolchain and
run bundled UVM. This guide covers test selection, DPI choices, and debugging.
For release installation and compatibility, use the
[release matrix](conformance/uvm_release_matrix.md).

## A minimal testbench

Save this as `smoke.sv`:

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;

class smoke_test extends uvm_test;
  `uvm_component_utils(smoke_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("SMOKE", "Hello from UVM", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test();
endmodule
```

```bash
iverilog -g2017 -uvm -s top -o smoke.vvp smoke.sv
vvp smoke.vvp +UVM_TESTNAME=smoke_test
```

Expect `[SMOKE] Hello from UVM`, normal completion, and zero UVM errors/fatals.
This checks startup only. A real test must also prove its intended traffic and
checking occurred.

## Test selection

- Put compiler options before source files. `-s top` chooses the top module.
- `+UVM_TESTNAME=name` selects the test when `run_test()` has no argument.
  A hardcoded `run_test("name")` supplies the name itself.
- Runtime plusargs include `+UVM_VERBOSITY=UVM_HIGH`.
- Use `vvp smoke.vvp +ntb_random_seed=123` for reproducible root RNG seeding.
  Supply one decimal value from 0 through 4294967295. Omitting it retains the
  deterministic default; malformed or duplicate seed options are rejected.
- The language edition and UVM release are independent choices. Explicitly
  select `-g2012`, `-g2017`, or `-g2023` when recording evidence.

Examples in [`tests/`](../tests) cover sequences, drivers, configuration,
virtual interfaces, TLM, and registers. Some need extra flags or native code;
[the regression runner](../.github/uvm_test.sh) records those requirements.

## DPI choices

**Default: real DPI.** `-uvm` loads the installed Icarus UVM DPI backend for
regex matching, command-line access, and `uvm_hdl_*` register backdoor access.
The source library remains unmodified. See the
[frontend reference](uvm_frontend.md) for discovery and loading details.

**Optional fallback:** `--uvm-no-dpi` defines `UVM_NO_DPI` and uses UVM's
SystemVerilog fallbacks. Regex behavior differs and native `uvm_hdl_*` backdoor
access is unavailable; frontdoor access and a user-defined SystemVerilog
`uvm_reg_backdoor` are separate mechanisms. A fallback run is not real-DPI
qualification. A missing installed DPI module also produces a warning and
selects this fallback, so inspect diagnostics.

**Your own DPI libraries:** load them explicitly with `vvp -d ./mylib.so`.
Use the platform's shared-library build flags and installed `svdpi.h`.
C-to-SystemVerilog exports require the generated `.dpiexport.c` companion.
DPI imports and exports have tested subsets; legal array forms and other ABI
corners remain unsupported. Consult clauses 35 and Annex H in the
[conformance matrix](conformance/matrices/ieee1800_2017_clause_matrix.md).

## Regression and diagnostics

Run `PATH="$PWD/install/bin:$PATH" bash .github/uvm_test.sh` from the
repository root. The runner compiles in `-g2012`, reports pass/fail/skip counts,
and prints whether it exercised real DPI or fell back to `UVM_NO_DPI`.
Check that mode alongside the result. Its shared temporary artifacts mean
concurrent runs or replacing the installation during a run can invalidate
results; run the frontend relocation gate separately, last.

Warnings and `sorry` diagnostics can signal missing semantics. Do not accept
a passing marker as proof that a warned-about feature works. In particular,
compilation, startup, library smoke tests, and complete application verification
are different evidence levels.

Use [current evidence](conformance/CURRENT_WORK.md) for recorded results and
the [clause matrix](conformance/matrices/ieee1800_2017_clause_matrix.md) for
feature boundaries. Report bugs with the exact compiler/runtime paths,
commands, source, and expected versus actual output.
