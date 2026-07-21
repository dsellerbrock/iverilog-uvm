# Running UVM on this fork

This guide covers compiling and running testbenches built on the
[Accellera UVM Core library](https://github.com/accellera-official/uvm-core)
with this fork's `iverilog`/`vvp`. For a one-screen version, see the
[README quick start](../README.md#running-a-uvm-testbench).

The UVM sources are vendored as the `uvm-core/` git submodule:

```bash
git submodule update --init      # populates uvm-core/
```

The library is used **unmodified** — no simulator-specific patches. That is a
project rule (see the
[manifesto](conformance/iverilog_ieee1800_uvm_manifesto.md)): when UVM breaks,
the simulator gets fixed, not the library.

## Canonical invocation

With an installed toolchain, `-uvm` wires up UVM for you — sources, include
path, compile order, and the standard UVM DPI runtime:

```bash
iverilog -g2012 -uvm my_testbench.sv -s top -o sim.vvp
vvp sim.vvp +UVM_TESTNAME=my_test
```

This is the recommended flow; it needs no UVM paths and no `-M`/`-m`/`-d`
runtime arguments, and it enables the real UVM DPI layer automatically. See
[docs/uvm_frontend.md](uvm_frontend.md) for how the front end resolves and
loads these resources, and for the overrides (`--uvm-home`, `--uvm-no-dpi`,
`--uvm-version`).

| Element | Why |
|---|---|
| `-g2012` | Selects IEEE 1800 SystemVerilog mode. Required; UVM will not parse without it (`-uvm` raises the generation to this if left at a non-SV default). |
| `-uvm` | Adds the installed UVM sources and DPI runtime automatically. |
| `-s top` | Selects the top module when there is more than one candidate. |
| `+UVM_TESTNAME=...` | Selects the test at runtime when the testbench calls `run_test()` with no argument. A hardcoded `run_test("name")` needs no plusarg. |

Standard UVM plusargs read via `$value$plusargs` work, e.g.
`+UVM_TESTNAME`, `+UVM_VERBOSITY=UVM_HIGH`.

### Manual invocation (advanced / working from the source tree)

Without an installed toolchain — for example running straight from a build
tree — you can still name the UVM sources explicitly. `uvm_pkg.sv` must
precede your testbench, and `-I uvm-core/src` makes the includes resolve:

```bash
iverilog -g2012 -I uvm-core/src -DUVM_NO_DPI -o sim.vvp \
  uvm-core/src/uvm_pkg.sv my_testbench.sv
vvp sim.vvp +UVM_TESTNAME=my_test
```

`-DUVM_NO_DPI` selects UVM's pure-SystemVerilog fallbacks (no DPI object to
build); see [DPI and UVM](#dpi-and-uvm) for running the real DPI layer this
way. The `-uvm` flow above does all of this for you and enables DPI by
default.

## Minimal smoke test

```systemverilog
// smoke.sv
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
iverilog -g2012 -I uvm-core/src -DUVM_NO_DPI -o smoke.vvp \
    uvm-core/src/uvm_pkg.sv smoke.sv
vvp smoke.vvp +UVM_TESTNAME=smoke_test
```

Expected: `UVM_INFO ... [SMOKE] Hello from UVM` followed by a UVM report
summary with `UVM_ERROR : 0` / `UVM_FATAL : 0`. Compilation of the full UVM
library takes a couple of seconds.

The ~190 testbenches in [`tests/`](../tests) are all built exactly this way
(see [`.github/uvm_test.sh`](../.github/uvm_test.sh)) and are the best source
of working examples — sequences, drivers, monitors, config-db, virtual
interfaces, the register layer, TLM ports, coverage, and so on.

## Compile-time warnings

Compiling the full UVM library prints a number of `warning:` lines
(compile-progress notes on constructs with known corners) and two `sorry:`
lines for `export "DPI-C"` (not supported — see below). These are loud by
design — the project forbids *silent* fallbacks — and do not, by themselves,
indicate a broken simulation: the full UVM regression runs green with these
warnings present.

## DPI and UVM

UVM has an optional DPI-C layer (regular-expression matching, command-line
processor, HDL backdoor access). This fork implements `import "DPI-C"`
(see [README — DPI-C](../README.md#dpi-c--substantial)), and `uvm_pkg.sv` compiles
**without** `-DUVM_NO_DPI` (exit status 0; the only diagnostics are recorded
sorries for `export "DPI-C"` and the 1024-bit `uvm_hdl_*` vector functions).

However, *running* with the real DPI layer requires building UVM's
`uvm_dpi.cc` against a simulator HDL backend that this fork does not provide
(`uvm_hdl.c` expects a VCS/Questa/Xcelium-style backend), and `export "DPI-C"`
(C code calling SystemVerilog) is not supported. So in practice:

- **Use `-DUVM_NO_DPI`.** This is the supported configuration; the entire UVM
  regression suite runs this way. UVM falls back to SystemVerilog
  implementations of regex matching and the command-line processor.
- Consequences of `UVM_NO_DPI`:
  - `uvm_hdl_deposit`/`uvm_hdl_read` (the DPI register **backdoor** path)
    return failure — use frontdoor register access, or a user-defined
    `uvm_reg_backdoor` subclass (pure SystemVerilog), which works.
  - Component-name checks and glob-style regex use the simpler
    non-DPI code paths (UVM reports this with `NO_DPI_*` info messages).
- **Your own DPI code does not need `UVM_NO_DPI` to be off.** User
  `import "DPI-C"` functions work normally alongside a `UVM_NO_DPI` build of
  UVM; compile them into a shared library and load it with `vvp -d`:

```bash
gcc -shared -fPIC -o mylib.so mylib.c
vvp -d ./mylib.so sim.vvp +UVM_TESTNAME=my_test
```

(Note the `./` — the path is passed to `dlopen(3)`, which searches system
library paths unless the name contains a slash.)

## Running the UVM regression suite

From the repository root, with the built compiler on `PATH`:

```bash
PATH="$PWD/install/bin:$PATH" ./.github/uvm_test.sh
```

This compiles and runs every `tests/*.sv` against the vendored UVM library
and scores each by explicit pass/fail evidence (a test with no PASS marker
and no error counts as a **failure** — silent no-output runs are not scored
green). Per-test plusargs and extra compile flags (e.g. `-gspecify` for the
timing-check tests) are declared in tables at the top of the script.

The known-limitation skip list is currently **empty** — every test runs.
(`reg_basic_test` was once skipped as "needs DPI backdoor access"; that
diagnosis was wrong — the real cause was a compiler bug in duplicated
function-call expressions, fixed 2026-07-18, and a user-defined
`uvm_reg_backdoor` never needed DPI. The correction is recorded in
`.github/uvm_test.sh`.)

## Known UVM-visible limitations

- The `uvm_hdl_*` DPI register **backdoor** path is unavailable (needs
  `export "DPI-C"`); frontdoor access and user-defined `uvm_reg_backdoor`
  classes work.
- `export "DPI-C"` is a loud sorry; C-to-SV calls will not link.
- `std::randomize(var)` (scope form) returns success without randomizing —
  loud one-time warning.
- See the [IEEE 1800-2017 clause matrix](conformance/matrices/ieee1800_2017_clause_matrix.md)
  for the full per-clause disposition and recorded corners.
