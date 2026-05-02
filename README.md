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
| `randomize()` unconstrained | ✅ | `rand` properties — `randc` currently behaves as `rand`, see Phase 63 / Issue C1 |
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
| OpenTitan UART DV `uart_smoke_vseq` linear progress | ✅ | Phase 60-61d: smoke advances ~1.76ms sim time in 2hr wallclock without crashing (was 30µs hang). 0 fatals. End-to-end completion is throughput-bound, not bug-bound — see CHANGES.md §12 |
| `pkg::func()` inside class method | ✅ | Was previously mis-resolving to virtual-method-on-this — Phase 25 |
| `inside { queue }` runtime membership | ✅ | `%inside/arr` opcode; correctly terminates `while inside` loops |
| Queue `.sort()`, `.rsort()`, `.unique()` | ✅ | vec4/real/string elements; iterator-arg form accepted |
| Enum `.name()/.next()/.prev()/.first()/.last()` | ✅ | Both no-paren and paren forms |
| `Class::static_func` (no-parens form) | ✅ | `MyClass::type_name` resolves to function call |
| `$cast(class_property, src)` | ✅ | Direct property-store sequence |
| `pkg::var = expr` assignment | ✅ | Phase 10 — rules in `statement_item`; both `IDENTIFIER` and `TYPE_IDENTIFIER` lvalue forms handled |
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
| Output-arg into indexed property (`cfg.q[key]`) | ✅ | Verified by audit 2026-05-01; OT-DV Issue #27 may be a different shape |
| `q.push_back("str")` element-type dispatch | ✅ | Phase 50d — was using value-expr type, now uses queue's element type |
| `pre_randomize()` / `post_randomize()` callbacks | ✅ | Phase 50e — tgt-vvp emits `%callf/void` to inherited hooks around `%randomize` |
| `cfg.aa["key"]` read via class-property chain | ✅ | Phase 50f — `draw_select_vec4` distinguishes assoc-compat from queue containers |
| Deferred interface task dispatch (parameterized callers) | ✅ | Phase 54 — emits `$ivl_iface_late$<iface>$<method>` NetSTask, tgt-vvp resolves at code-gen via design walk; pform default args evaluated in caller scope |
| Same-scope `@cb` (clocking-block) event | ✅ | Phase 55 — scope-walk lookup of pform `Module::clocking_blocks` rewrites `@cb` → underlying `@(posedge clk)` |
| Z3 BV/Bool sort coercion in `randomize()` | ✅ | Phase 56 — SV `!x` produces `(not x)` IR; ITE returns `BV[1]`; `and`/`or` operands coerced via `(a != 0)` |
| `wait()`-loop sensitivity through VIF chain | ✅ | Phase 58 — `try_set_vif_anyedge` recurses NetEUnary/NetESFunc; `vpi_get_value_vector_` zeros buffer to fix bval bleed |
| Autotask self-frame pinning across forks | ✅ | Phase 59 — closes "cfg=null mid-method" and "try_next_item dispatch fail" by retaining the autotask's own frame in `owned_context` |
| Time literals in class methods | ✅ | Phase 60 — `pform_set_scope_timescale` propagates the file's `` `timescale`` to PClass; `#100ns` no longer evaluates to 0 or 1e9× too long |
| Runtime virtual-dispatch suffix lookup O(1) | ✅ | Phase 61c — `runtime_lookup_code_scope_by_suffix_` uses a parallel suffix index instead of linear scan; ~57% of CPU eliminated under heavy virtual-method workloads |
| anyedge_aa null-context fallback gating | ✅ | Phase 61/61b — skip recursive recv_object delivery to no-waiter contexts; hoist malloc_usable_size bounds check; closes 30µs CPU-loop hang in OT smoke |
| `randc` cyclic semantics | ✅ | Phase 62a — per-property history bitmap; randomize() picks unused values until cycle exhausts (capped at 16-bit width = 65536 period). 2-bit randc visits all 4 values uniquely in first cycle. |
| `dist` weighted distribution | ✅ | Phase 62b — `(dist <expr> (b W <range>) ...)` IR opcode; Z3_optimize_assert_soft per branch with weight. `x dist {0:=90, 1:=10}` produces 91/9 over 100 iterations. |
| `soft` constraints | ✅ | Phase 62c — wraps in `(soft <expr>)` IR; Z3_optimize_assert_soft default weight 256 dominates bvxor diversity. Hard constraints still override soft. |
| Streaming concatenation `{<<N{x}}` (RHS) | ✅ | Phase 62d — bit-reverse and chunk-reverse via NetEConcat of NetESelect. `{>>}` identity. Width%N remainder placed at LSB. LHS form deferred. |
| Concurrent assertions `assert property` | ✅ Basic | Phase 62f — `@(clk) [disable iff (rst)] a |-> b else <fail>;` synthesizes always block; `|=>` approximated as `|->`; sequence/property declarations still drop body |
| Tagged unions (parse) | ✅ | Phase 62 / I6 — `union tagged { ... }` parses, lowered to plain union (tag values not enforced). |
| `std::randomize(var) with{}` (parse) | ⚠ Stub | Phase 62e / C6 — bare-statement and void'() forms now parse (no Malformed-statement error). Runtime constraint solving for non-class vars still no-op. |
| Concurrent assertions (`assert property`) | ✅ Basic | Phase 62f — basic forms work; sequence/property declarations + edge primitives ($rose etc.) still stub |
| Coverage `cross` / `illegal_bins` | ⚠ Stub | I1 deferred — parser drops cross items at parse.y:2433; needs covergroup runtime + tgt-vvp metadata. |
| `uvm_object.print()` printer dispatch | ⚠ Stub | I2 deferred — virtual dispatch on uvm_table_printer::emit falls through to uvm_printer base. Same family as Phase 61c suffix-index work. |
| `uvm_resource_db#(T)::set/read_by_name` | ⚠ Stub | C3 deferred — runtime warnings on parameterized class typed pool ("signal assoc on unexpected container type"). |
| `uvm_cmdline_processor.get_args()` | ⚠ DPI | C4 deferred — needs DPI lib (script: scripts/build_uvm_dpi_iverilog.sh) plus downstream vthread::pop_str robustness fix. |
| `wait()`-loop sensitivity through virtual-interface chain | ⚠ Open | iverilog's nex_input on a `NetEProperty` chain returns the root `this` nexus, not the iface signal — see Issue #28 |
| UVM port-imp virtual dispatch (`seq_item_port.try_next_item`) | ⚠ Open | Falls through to `uvm_sqr_if_base` error stub — see Issue #29 |
| Class property handle preservation across method-internal control flow | ⚠ Open | `cfg` reads non-null at `a_channel_thread` entry, null 20 ns later in callee — see Issue #30 |

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
| `set_active()` silently dropped | **0 / 27** | ✅ closed by Phase 44 (parser) |
| `apply_reset()` silently dropped (vif method) | **0 / 27** | ✅ closed by Phase 45 (vif dispatch) |
| `dv_base_env: No clk_rst_if called <ral_name>` | 27 / 27 | residual; OpenTitan testbench-setup gap (`cfg.ral.get_type_name()` returns "" under iverilog, sending `is_default_ral_name=0`). All 27 tests still reach **TEST PASSED CHECKS** before this fatal -- dvsim flags fail because UVM_FATAL is in the log; the test scaffolding (uvm_report_catcher) catches and downgrades it. |

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

Phase 45 (`elab_type.cc` `elaborate_interface_type_` + `elaborate.cc`
`PCallTask::elaborate_method_`) makes virtual-interface task dispatch
work. The netclass_t cached for an interface was missing its
`class_scope_`, so `method_from_name` always returned null and
`resolve_method_call_scope` fell through to the "class scope incomplete"
warn-and-noop branch. Now the elaborator attaches the actual interface
instance scope (looking up the module name in root scopes, then walking
each root's children) so per-instance task and function children are
visible. The dispatch site additionally passes `nullptr` (instead of the
receiver expression) for `use_this` when `class_type->is_interface()` is
true -- interface tasks aren't class methods and have no `this` first
port. This fixes `cfg.clk_rst_vif.apply_reset()` on UART DV: without
`apply_reset()` actually running, the test never deasserted reset, the
clock generator stayed paused on `wait_for_reset`, and every CSR access
hit DV_WAIT_TIMEOUT. Repro: `tests/vif_method_test.sv`.

Phase 46 (`elab_expr.cc` `PETypename::elaborate_expr`) redirects to the
interface instance scope when the type name shadows an instance.
`uvm_config_db#(virtual clk_rst_if)::set(null, "*.env", "clk_rst_vif",
clk_rst_if)` was storing null because the parser routes the bare
`clk_rst_if` reference (TYPE_IDENTIFIER) through `data_type ->
typeref_t -> PETypename`, whose `elaborate_expr` returned an empty
`NetECString`. The fix: when the typeref names a typedef AND there's
an interface scope visible from the call site with the same name,
build a `NetEScope` wrapping that instance scope so callers receive
the real interface handle. Repro: `tests/iface_arg_pass_test.sv`.

Phase 47 (`elab_scope.cc` `specialization_perf_base_label_`) makes the
parameterized class specialization cache key stable for interface
types. Phase 45's lazy `class_scope_` attachment caused the same
`virtual <iface>` parameter to hash to two different cache entries
("clk_rst_if" before lazy attach, "tb.clk_rst_if" after), producing
two distinct `uvm_resource#(virtual <iface>)` netclass_t specs whose
static `my_type` instances diverged. The resource pool's type filter
then rejected the SET-time entry at GET time. Use the bare type name
for `is_interface()` netclass_t so the label is canonical and
time-invariant. Repro: `tests/cfgdb_iface_shadow_test.sv`.

Phase 48 (`vvp/vthread.cc` `of_RANDOMIZE`) walks the class inheritance
chain to apply constraints declared on base-class rand properties.
Previously `defn->constraint_count()` only consulted the runtime
class itself, so constraints declared in a base class on its own
rand properties were silently dropped when the runtime instance was
deeper-derived. UART DV's `uart_period_glitch_pct` (declared with
`inside {[0:10]}` in `uart_base_vseq`) was tripping
`uart_agent_cfg`'s `pct < 20` fatal at the start of every body().
Repro: `tests/rand_inh_constraint_test.sv`.

Phase 49 (`elaborate.cc`, after constraint-block elaboration) auto-
generates an `inside` constraint for every rand/randc property whose
type is an enum. Without this, `%randomize` seeded the property with
raw `rand()` bits and almost never landed on a valid enum label, so
downstream `case (field) ... default: $fatal` traps fired. Auto-emit
`(inside p:N:W c:val1 c:val2 ...)` from the enum's runtime values;
the existing Z3 path handles it. Repro: `tests/rand_enum_test.sv`.

Phase 50 (`vvp/compile.cc` `runtime_lookup_code_scope_by_suffix_`):
The VVP runtime's fallback suffix-matching dispatch extracted the last
class-name component before the method name and scanned the global
`runtime_code_scope_map` for any entry ending with that suffix.  This
works for user class names, but parameterised class specialisations
generated by iverilog receive auto-incremented `_ivl_N` names that are
**package-local counters** — the same N (e.g. `_ivl_26`) independently
appears in `dv_lib_pkg` (for `dv_base_driver`) and `push_pull_agent_pkg`
(for `push_pull_driver`).  The suffix matcher then dispatched
`uart_driver.build_phase` to `push_pull_driver.build_phase`, causing
the UART DV scoreboard and sequencer wiring to silently fail.  Fix:
skip suffix lookup entirely when the extracted class component starts
with `_ivl`; exact label matches still work normally.

Phase 51 (`vvp/vpi_cobject.cc`, `tgt-vvp/draw_vpi.c`, `vvp/lexor.lex`,
`vvp/parse.y`): When a class string property is passed as the lvalue
of `$value$plusargs`, the compiler emits a `&CPS` (class-property
string) token pairing the cobject net label with the property index.
`vpip_make_cobject_property_string_var` creates a
`__vpiClassPropertyStringVar` handle that reads and writes the specific
string slot in the live `vvp_cobject` via `get_string`/`set_string`.
Previously, `vpi_put_value(vpiStringVal)` on the outer `vpiClassVar`
handle was a no-op (the property index was not carried), so plusarg
strings never propagated into class object fields.
Repro: `tests/plusargs_class_string_test.sv`.

Phase 8 (`parse.y` constraint grammar): `dist { [lo:hi] :/ weight }` is
lowered to `X inside { [lo:hi] }` — weights are silently dropped and the
range is forwarded to the existing Z3 `inside` path, which enforces the
value domain.  Previously the entire `dist` expression was discarded,
making `rand` variables with only `dist` constraints unconstrained.  The
`DV_COMMON_CLK_CONSTRAINT` macro in OpenTitan uses `dist` to restrict
`clk_freq_mhz` to [5:100] MHz; without this fix the generated clock
frequency could be any unsigned int value, producing non-functional
simulations.  All scalar (`val := weight`, `val :/ weight`) and range
(`[lo:hi] := weight`, `[lo:hi] :/ weight`) forms are handled, including
`soft` and `A -> soft B dist` implications.  Proper weighted distribution
is tracked as a future TODO. Repro: `tests/dist_constraint_test.sv`.

Residual UART DV regression failures (Phase 51 baseline):

| Failure | Count | Reason |
|---|---|---|
| `csr_wr` Timeout at 2 ms | ~7 | TL bus driver does not respond to CSR transactions; tracked separately. Test runs full 2 ms simulated time, root cause is the TL-UL bus driver not responding (not an iverilog parsing/elaboration issue). |

The hand-curated `scripts/compile_uart_dv.sh` path also still works
for end-to-end `uart_smoke_vseq` runs (with `+timescale+1ns/1ps` now
applied via a prelude `.scr` file, matching the dvsim flow).

---

## Test Results

All UVM regression tests pass (~30 tests including new Phase 50d/e/f, 54, 55, 56 reproducers):

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
| `dist_constraint_test.sv` | `dist` ranges enforced via `inside`; all `clk_freq_mhz` in [5:100] (Phase 8) | ✅ PASS |
| `pre_post_randomize_test.sv` | `pre_randomize`/`post_randomize` callbacks fire and counters increment (Phase 50e) | ✅ PASS |
| `post_member_assoc_test.sv` | `cfg.aa["key"] = 99` inside `post_randomize` persists across class-property chain (Phase 50f) | ✅ PASS |
| `cfg_aa_read_test.sv` | `cfg.aa["key"]` read via class-property chain returns the assoc-stored value (Phase 50f) | ✅ PASS |
| `queue_push_test.sv` | `q.push_back("str")` for string queue dispatches via element type (Phase 50d) | ✅ PASS |
| `iface_late_apply_test.sv` | Interface task call from a class through `cfg.vifs[key].apply_reset()` (Phase 54) | ✅ PASS |
| `iface_late_param_test.sv` | Parameterized base sequence with fork/join_none + wait fork pattern (Phase 54) | ✅ PASS |
| `wait_clks_test.sv` | `wait_clks(N)` over `clocking cb @(posedge clk)` waits the right number of cycles (Phase 55) | ✅ PASS |
| `plusargs_class_string_test.sv` | `$value$plusargs` writes to class string property via `&CPS` handle (Phase 51) | ✅ PASS |

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
