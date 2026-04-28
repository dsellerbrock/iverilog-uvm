# Icarus Verilog — UVM/SystemVerilog Experimental Fork

[![CI](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/main.yml/badge.svg?branch=development)](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/main.yml)

> ## ⚠ EXPERIMENTAL — DO NOT USE FOR SERIOUS WORK ⚠
>
> **This is a toy/research fork. All code is guilty until proven innocent.**
> It must not be used for production, tapeout, or any work where correctness
> matters until the changes have been:
>
> - Thoroughly tested against a broad regression suite
> - Reviewed and accepted into an official upstream release
> - Independently verified by the wider Icarus Verilog community
>
> **What this fork does:** Adds experimental, AI-assisted SystemVerilog and UVM
> support. Many constructs are stubbed, fall back silently, or produce incorrect
> results in edge cases. The changes have not been through normal upstream
> code review.
>
> **Use the official Icarus Verilog** at https://github.com/steveicarus/iverilog
> for any real work. This fork is for exploration and upstream contribution
> purposes only.
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
| OpenTitan UART DV compile + UVM boot | ✅ | Full RTL+DV bundle compiles; runs uart_base_test through RAL setup |
| OpenTitan UART DV `uart_smoke_vseq` end-to-end | ✅ | Test sequence runs to completion, watchdog drains, exit=0 |
| `pkg::func()` inside class method | ✅ | Was previously mis-resolving to virtual-method-on-this — Phase 25 |
| `inside { queue }` runtime membership | ✅ | `%inside/arr` opcode; correctly terminates `while inside` loops |
| Queue `.sort()`, `.rsort()`, `.unique()` | ✅ | vec4/real/string elements; iterator-arg form accepted |
| Enum `.name()/.next()/.prev()/.first()/.last()` | ✅ | Both no-paren and paren forms |
| `Class::static_func` (no-parens form) | ✅ | `MyClass::type_name` resolves to function call |
| `$cast(class_property, src)` | ✅ | Direct property-store sequence |
| `pkg::var = expr` assignment | ⚠ Deferred | LALR conflict, needs grammar restructure |
| Full UVM library end-to-end | ⚠ Partial | Phase infrastructure works; some gaps remain |
| `dist` weighted distribution | ⚠ Stub | Parses without crashing — actual weighting TODO (Phase 30 / Issue #12) |
| `std::randomize(var) with {...}` | ⚠ Stub | Returns success; variable retains current value |
| Concurrent assertions (`assert property`) | ⚠ Stub | Parses with `\|->`, `\|=>`, `disable iff`; semantics TODO (Phase 31) |
| SVA `default disable iff` / `default clocking` | ⚠ Stub | Parses silently at module scope (Phase 32) |
| SVA `sequence ... endsequence` / `property ... endproperty` | ⚠ Stub | Parses via error recovery; body dropped (Phase 33) |
| SVA sampling (`$rose/$fell/$stable/$past`) | ⚠ Stub | Returns safe defaults; no clock-edge sampling |
| Clocking blocks `@(iface.cb)` + `iface.cb.sig` | ✅ | Flat rewrite to underlying interface signals |
| Program blocks | ✅ | Treated like modules |
| Output-arg into nested class property (e.g. `env.cfg.vif`) | ✅ | inout writeback through `cfg.vif`, `env.cfg.vif`, etc. |
| Output-arg into indexed property (`cfg.q[key]`) | ⚠ Deferred | Writeback skipped — see Issue #27 OpenTitan DV |

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

### OpenTitan DV (dvsim + fusesoc)

This iverilog fork plugs into OpenTitan's native DV flow. Drop
`iverilog.hjson` (in this repo's companion OpenTitan tree) into
`hw/dv/tools/dvsim/` and run:

```bash
PATH="$(pwd)/install/bin:$PATH" \
UVM_HOME=/path/to/uvm-core \
opentitan/util/dvsim/dvsim.py \
    opentitan/hw/ip/uart/dv/uart_sim_cfg.hjson \
    --tool=iverilog -i smoke
```

dvsim invokes `fusesoc --tool=icarus --setup` to produce a `.scr`
filelist + Makefile, then iverilog consumes the filelist directly. No
hand-curated source list is needed. (See the [iverilog-uvm OpenTitan
fork](https://github.com/dsellerbrock/opentitan-iverilog) for the
patches to `dv_base_env.sv`, `dv_base_test.sv`, and the
`hw/dv/tools/dvsim/iverilog.hjson` config.)

**Status (2026-04-27)**: dvsim → fusesoc → iverilog runs the **full UART
DV regression**. All 27 vseqs reach `TEST PASSED CHECKS` at the UVM
level:

| Stage | Tests | Result |
|---|---|---|
| Build (full RTL+DV bundle, fusesoc-resolved) | 1 | ✅ |
| Smoke + CSR (smoke, csr_hw_reset, csr_rw, csr_aliasing, csr_bit_bash, csr_mem_rw_with_rand_reset, same_csr_outstanding) | 7 | ✅ all PASSED CHECKS |
| Functional (tx_rx, fifo_full, fifo_overflow, fifo_reset, intr, intr_test, loopback, noise_filter, perf, rx_oversample, rx_parity_err, rx_start_bit_filter, tx_ovrd, long_xfer_wo_dly) | 14 | ✅ all PASSED CHECKS |
| Stress + sec_cm + alerts (stress_all, stress_all_with_rand_reset, sec_cm, alert_test, tl_errors, tl_intg_err) | 6 | ✅ all PASSED CHECKS |

The null-map UVM_ERROR is now resolved (Phase 36 — task-call routing
for `void'(<assoc>.first/last/next/prev(key))` plus
`foreach_index_type_t` propagation in `elab_sig.cc`). UVM
`get_default_map()` now returns the registered map, the m_maps
traversal works, and frontdoor register access reaches the bus.

The TYPNTF UVM_ERROR is resolved (Phase 37 — vvp/vthread.cc
`vthread_get_rd_context_item_scoped` now prefers the rd-context head
over deeper wt entries when both match, so mutually-recursive
class-handle returns from `find_override_by_type` no longer collapse
to null).

The sequencer-wiring UVM_FATAL is resolved (Phase 38 — `elab_type.cc`
`find_foreach_path_root_type_` and `find_foreach_selected_path_type_`
now walk the super-class chain when locating an inherited assoc-array
property, so `foreach (cfg.m_tl_agent_cfgs[i])` in
`cip_base_env::end_of_elaboration_phase` correctly iterates and binds
the reg-map's bus sequencer).

Function-local `static` is now correctly persistent (Phase 39 —
`elaborate.cc`:`PFunction::elaborate` splits `var_inits` by lifetime
and emits static-lifetime initializers as a one-shot `IVL_PR_INITIAL`
process, instead of prepending them to the function body where they
would re-run on every call). This may unblock UVM internals that rely
on per-function static counters or visited sets.

Simple-path `foreach (<inherited-prop>[i])` is now also covered (Phase
40 — `elab_type.cc`:`find_foreach_simple_class_property_index_type_`
walks the netclass_t super-class chain). Phase 38 only covered the
multi-segment `cfg.<inherited-prop>[i]` case; OpenTitan also hits the
simple-path case via `cip_base_env_cfg::check_shadow_reg_alerts`'s
`foreach (ral_models[i])`.

Nested `foreach` reusing the loop-variable name now correctly shadows
(Phase 41 — `elab_type.cc`:`find_assoc_foreach_index_signal_` no longer
walks up the scope chain when the immediate scope is a `$ivl_foreach...`
autobegin). Previously, `foreach (regs[i])` inside `foreach (m_aa[i])`
mis-bound the inner `i` to the outer foreach's signal, so the inner
foreach's variable initialization corrupted the outer foreach's loop
state -- making the outer iterate forever with the same key. This was
the residual hang in OpenTitan UART DV's `extract_common_csrs`.

Residual UVM messages on the full 27-test regression:

| Severity | Count | Reason |
|---|---|---|
| `UVM_ERROR null map` | **0 / 27** | ✅ closed by Phase 36 |
| `UVM_ERROR [TYPNTF]` factory override | **0 / 27** | ✅ closed by Phase 37 |
| `UVM_FATAL [SEQ]` sequencer not supplied | **0 / 27** | ✅ closed by Phase 38 |
| `csr_wr` timeout at 0 ps | **0 / 27** | ✅ closed by Phase 43 (default timescale) |

Phase 42 (`vvp/class_type.cc` — `property_bit::{get,set}_vec4`) demotes
the out-of-range-index assertion to a rate-limited soft-fail. The
PEEK_VEC4-UF cascade can push an X value into a class fixed-size-array
property write/read; aborting via assert took down 14 otherwise-clean
UART tests. Warn-and-skip lets diagnosis continue without losing all
prior progress to a single bad index.

Phase 43 (`opentitan/hw/dv/tools/dvsim/iverilog.hjson` — prelude
`+timescale+1ns/1ps`) sets a default timescale before any module is
parsed. OpenTitan DV packages don't declare their own `\`timescale`;
under VCS/Xcelium/dsim it's set via the simulator's `-timescale 1ns/1ps`
flag. iverilog has no equivalent CLI option, so without an explicit
prelude every `#(N * 1ns)` in task bodies (notably `DV_WAIT_TIMEOUT`)
collapses to 0 ticks and `csr_wr` fires the timeout branch immediately.
With the prelude, simulation actually advances real time and tests run
through their bodies. Repro: `tests/delay_arg_timescale_test.sv`.

Phase 44 (`parse.y` — `expr_primary '.' IDENTIFIER ...` rule) preserves
the receiver expression when the parser falls into the method-call form
of `subroutine_call`. Previously the rule built a name-only `PCallTask`
and `delete $1`'d the receiver, which silently dropped the prefix. This
hit OpenTitan tb.sv where every clock interface uses
`clk_rst_if clk_rst_if(...)` (instance name == type name), making the
lexer pick `TYPE_IDENTIFIER` over `IDENTIFIER` for the leading token --
which routed `clk_rst_if.set_active()` through this broken rule and
turned it into a bare `set_active()` call that nothing matched. Without
`set_active()` the interface stays inactive (no clock, no reset) and
every UART DV test deadlocked at the first CSR access. The fix splices
the leading `PEIdent`'s path into the call's hierarchy. Repro:
`tests/iface_name_shadow_test.sv`.

The hand-curated `scripts/compile_uart_dv.sh` path also still works
for end-to-end `uart_smoke_vseq` runs.

---

## Test Results

All 21 UVM regression tests pass:

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
| `dist_test.sv` | `dist` weighted constraint parses; randomize succeeds 10/10 | ✅ PASS |

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
