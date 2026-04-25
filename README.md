# Icarus Verilog — UVM/SystemVerilog Experimental Fork

[![CI](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/main.yml/badge.svg?branch=development)](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/main.yml)

> **Experimental research fork.** Adds UVM and IEEE 1800-2012 SystemVerilog support to
> [Icarus Verilog](https://github.com/steveicarus/iverilog). Changes are under active
> development and being prepared for upstream submission. **Not for production use.**
>
> Full technical design document: [`CHANGES.md`](CHANGES.md)

---

## What This Fork Adds

Starting from Icarus Verilog's `master` branch, this fork adds end-to-end support for
running real UVM testbenches. The goal is to fix every gap between iverilog and the
[Accellera UVM Core library](https://github.com/accellera-official/uvm-core) — from
language constructs the compiler rejects, to runtime semantics that produce wrong
results — and upstream each fix as a minimal, reviewable patch.

### Feature Status

| Feature | Status | Notes |
|---|---|---|
| Classes, inheritance, polymorphism | ✅ | Full virtual dispatch across chains |
| Parameterized classes | ✅ | Type-param forward-ref recovery |
| `$cast()`, `$typename()` | ✅ | Runtime type checks |
| Queues, dynamic arrays, assoc arrays | ✅ | All element types; wait/wakeup on mutation |
| `mailbox`, `semaphore` | ✅ | Blocking and non-blocking forms |
| `fork`/`join`, `fork`/`join_none` | ✅ | Stable named-scope context binding |
| `randomize()` unconstrained | ✅ | All `rand`/`randc` properties |
| `randomize()` with constraint blocks | ✅ | Z3 SMT solver backend |
| `randomize() with { ... }` inline | ✅ | Constant, class-prop, and caller-scope vars |
| `rand_mode(0/1)` | ✅ | Per-property enable/disable |
| `constraint_mode(name, 0/1)` | ✅ | Per-constraint enable/disable |
| `@(posedge/negedge vif.clk)` | ✅ | Virtual interface class member events |
| `uvm_config_db #(virtual IF)::get()` | ✅ | Virtual interface passing |
| UVM phases (run, start, stop) | ✅ | Objection mechanism, phase hopper |
| UVM factory + type registration | ✅ | `create_object_by_type`, overrides |
| Sequencer/driver TLM | ✅ | `uvm_seq_item_pull_port`, `get_next_item` |
| TLM `put`/`get`/`peek` ports | ✅ | Blocking and non-blocking forms |
| Analysis ports (`write`) | ✅ | Subscriber callbacks |
| UVM register layer (basic) | ✅ | Backdoor write/read/mirror |
| `covergroup`/`coverpoint`/`bins` | ✅ | `sample()`, `get_inst_coverage()` |
| `import "DPI-C" function` | ✅ | Scalar int/real/void; `vvp -d lib.so` |
| String methods | ✅ | `toupper`, `tolower`, `getc`, `compare` |
| Class fixed-size array properties | ✅ | `int data[N]` member fields |
| OpenTitan `dv_base_reg_pkg` compilation | ✅ | Through `tl_agent_pkg` |
| `pkg::var = expr` assignment | ⚠ Deferred | LALR conflict, needs grammar restructure |
| Full UVM library end-to-end | ⚠ Partial | Phase infrastructure works; some gaps remain |
| `dist` weighted distribution | ⚠ Deferred | Not yet implemented |

---

## Quick Start

### Build

```bash
git clone https://github.com/dsellerbrock/iverilog-uvm.git
cd iverilog-uvm
git submodule update --init          # pulls uvm-core/
sh autoconf.sh
./configure --prefix=$(pwd)/install
make -j$(nproc)
make install
```

**Requirements:** `bison` ≥ 3.0, `flex`, `gperf`, a C++11 compiler, `libz3-dev`
(required for constrained randomization).

```bash
# Ubuntu/Debian
apt install -y autoconf gperf bison flex libz3-dev

# macOS (Homebrew)
brew install autoconf gperf bison flex z3
export PATH="$(brew --prefix bison)/bin:$PATH"
```

### Compile and Run a UVM Test

```bash
BIN=./install/bin

# Compile
$BIN/iverilog -g2012 \
  -I uvm-core/src \
  -DUVM_NO_DPI \
  -o sim.vvp \
  uvm-core/src/uvm_pkg.sv \
  your_testbench.sv

# Simulate
$BIN/vvp sim.vvp
```

### DPI-C Example

```bash
# Compile your C functions into a shared library
gcc -shared -fPIC -o mylib.so mylib.c

# Run with the library loaded
$BIN/vvp sim.vvp -d mylib.so
```

---

## Test Results

All 20 UVM regression tests pass:

| Test | What It Exercises | Result |
|---|---|---|
| `no_rand_test.sv` | Object creation, no randomize | ✅ PASS |
| `simple_rand_test.sv` | `randomize()` unconstrained | ✅ PASS |
| `constraint_test.sv` | `rand`/`constraint`/`inside` with Z3 | ✅ PASS |
| `seq_trace_test.sv` | Sequencer/driver TLM handshake | ✅ PASS |
| `tlm_debug_test.sv` | Blocking `put_port` producer/consumer | ✅ PASS |
| `analysis_test.sv` | `uvm_analysis_port` write to subscriber | ✅ PASS |
| `randomize_with_test.sv` | `randomize() with { }` inline constraints | ✅ PASS |
| `cross_var_test.sv` | Cross-variable constraint `a < b` | ✅ PASS |
| `rand_mode_test.sv` | `rand_mode(0)` / `rand_mode(1)` | ✅ PASS |
| `constraint_mode_test.sv` | Per-constraint enable/disable | ✅ PASS |
| `vif_probe.sv` | `@(posedge vif.clk)` edge detection | ✅ PASS |
| `vif_negedge_test.sv` | `@(negedge vif.clk)` and anyedge | ✅ PASS |
| `vif_config_db_test.sv` | `uvm_config_db #(virtual IF)::set/get` | ✅ PASS |
| `reg_basic_test.sv` | UVM register backdoor write/read/mirror | ✅ PASS |
| `coverage_basic_test.sv` | Covergroup sample, 50% coverage | ✅ PASS |
| `coverage_full_test.sv` | 2 coverpoints, 4 bins, 0→50→100% | ✅ PASS |
| `coverage_vals_test.sv` | Single-value bins, incremental coverage | ✅ PASS |
| `class_array_test.sv` | Class `int data[N]` FIFO round-trip | ✅ PASS |
| `dpi_basic_test.sv` | DPI `c_add`, `c_mul`, `c_factorial` | ✅ PASS |
| `dpi_real_test.sv` | DPI `c_sqrt`, `c_pow` with real args | ✅ PASS |

The branch also adds **83 new tests** to `ivtest/regress-sv.list` covering SV class
and container semantics at the language level.

---

## Repository Layout

```
iverilog/                    ← This repository (fork of steveicarus/iverilog)
├── uvm-core/                ← Accellera UVM Core (git submodule)
├── tests/                   ← UVM regression tests specific to this fork
├── ivtest/ivltests/         ← Upstream regression suite (+ new sv_*.v tests)
├── README.md                ← This file
└── CHANGES.md               ← Full technical design document for all changes
```

---

## Upstream Contribution Plan

These changes are being prepared for upstream submission to
[steveicarus/iverilog](https://github.com/steveicarus/iverilog). See
[`CHANGES.md`](CHANGES.md) for the complete breakdown: which commits are
upstream-ready, which need splitting, and which need maintainer discussion.

**Key upstream considerations:**

- **Patch size**: The large foundational commits need to be decomposed into
  focused single-feature patches before submission. The later phase commits
  (Phases 3–9) are closer to upstream-ready size.
- **Z3 dependency**: Constrained randomization (`randomize() with { }`) requires
  libz3 and will need `configure --with-z3` conditioning for upstream.
- **Test placement**: UVM-specific tests need to move from `tests/` to
  `ivtest/ivltests/` with `regress-sv.list` entries.

---

## How Icarus Verilog Works

Icarus Verilog is intended to compile ALL of the Verilog HDL, as described in
the IEEE 1364 standard, and a growing subset of IEEE 1800 SystemVerilog. It is
not aimed at being a simulator in the traditional sense, but a compiler that
generates code employed by back-end tools.

For the full Icarus Verilog home page: https://steveicarus.github.io/iverilog/

### Preprocessing

There is a separate program, `ivlpp`, that handles preprocessing — implementing
`` `include `` and `` `define `` directives, producing a single output file with line
number directives. See `ivlpp/ivlpp.txt` for details.

### Parse

The compiler parses Verilog source into a list of Module objects in "pform"
(`pform.h`). This is a direct reflection of the source structure with dangling
references still present. Use `-P <path>` on the `ivl` subcommand to dump the
pform for debugging.

### Elaboration

Takes the pform and generates a netlist. The driver selects the root module,
resolves references, and expands instantiations to form the design netlist.
Final semantic checks and simple optimizations are performed here.

Elaboration runs in two passes:

1. **Scope elaboration** (`elab_scope.cc`): Builds the `NetScope` tree, resolves
   parameters and `defparam` overrides.
2. **Netlist elaboration**: Traverses the pform again to generate structural and
   behavioural netlist from the fully-evaluated parameters.

### Optimization

A collection of target-independent processing steps: null effect elimination,
combinational reduction, constant propagation. Controlled by `-F` flags on `ivl`.

### Code Generation

The `emit()` method traverses the design netlist and calls target functions to
produce output. Select the target with `-t`. The primary target is `vvp`, which
produces VVP bytecode for the `vvp` runtime simulator.

### Attributes

The `$attribute` module item (and standard Verilog-2001 `(* *)` syntax) attaches
key-value string pairs to netlist objects. Used for communication between
processing steps.

---

## Building/Installing Icarus Verilog from Source

### Compile Time Prerequisites

```bash
# Ubuntu/Debian
apt install -y autoconf gperf make gcc g++ bison flex libz3-dev

# macOS (Homebrew)
brew install autoconf gperf bison flex z3
export PATH="$(brew --prefix bison)/bin:$PATH"
```

Full requirements:

- **GNU Make** — Makefiles use GNU extensions
- **ISO C++ compiler** — C++11 or later (`gcc`/`g++` or `clang++`)
- **bison** ≥ 3.0 — bison 2.x (shipped with older macOS) generates broken code
- **flex** — lexical scanner generator
- **gperf** ≥ 3.0 — keyword hash table generator
- **readline** ≥ 4.2 — for the interactive `ivl` subcommand
- **autoconf** ≥ 2.53 — to regenerate `configure` from source
- **libz3** — for constrained randomization (optional but recommended)

### Compilation

From a release tarball:

```bash
./configure
make
```

From git:

```bash
sh autoconf.sh
./configure --prefix=$(pwd)/install
make -j$(nproc)
```

Configure flags:

```
--prefix=<root>         Install prefix (default: /usr/local)
--enable-suffix[=<s>]   Add suffix to installed file names for parallel installs
--host=<host-type>      Cross-compile (e.g. x86_64-w64-mingw32 for Windows)
```

### Testing

```bash
make check
```

### Installation

```bash
make install
```

### Uninstallation

```bash
make uninstall
```

---

## Running `iverilog`

The preferred way to invoke the compiler is with the `iverilog`(1) command, which
drives `ivlpp` and `ivl` with appropriate flags. See the `iverilog`(1) man page.

### Hello World

```verilog
// hello.vl
module main();
  initial begin
    $display("Hello World");
    $finish;
  end
endmodule
```

```bash
iverilog hello.vl
./a.out
```

Use `-o` to name the output file.

---

## Unsupported Constructs

Icarus Verilog supports a growing subset of Verilog and SystemVerilog. Some
currently unsupported features:

- **Specify blocks** — parsed but ignored by default; limited support with `-gspecify`
- **`trireg`** — not supported; `tri0` and `tri1` are supported
- **Net delays** — `wire #N foo;` does not work; `wire #5 foo = bar;` (V2001 form) works
- **Full SystemVerilog** — the list of unsupported constructs is too large to enumerate;
  see https://steveicarus.github.io/iverilog/ and the bug tracker

---

## Nonstandard Constructs and Behaviors

Icarus Verilog includes features not part of the IEEE 1364 standard, and sometimes
gives extended meanings to standard features. See the "Icarus Verilog Extensions"
and "Icarus Verilog Quirks" sections at https://steveicarus.github.io/iverilog/.

---

## Credits

Icarus Verilog, `ivl`, and `ivlpp` are Copyright Stephen Williams (2000–2026).
UVM/SV fork maintained by Daniel Ellerbrock. AI-assisted development via Claude
(Anthropic).

[Accellera UVM Core](https://github.com/accellera-official/uvm-core) is Copyright
Accellera Systems Initiative, licensed under Apache 2.0.
