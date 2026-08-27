# Icarus Verilog — SystemVerilog / UVM fork

[![CI](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml)

An **experimental development fork** of [Icarus Verilog](https://github.com/steveicarus/iverilog)
targeting broad, measurable conformance with IEEE 1800-2017 and IEEE
1800-2023, the unmodified
[Accellera UVM Core library](https://github.com/accellera-official/uvm-core),
and representative OpenTitan and Caliptra RTL/DV workloads.

Language edition is selected with `-g`: `-g2012`, `-g2017`, `-g2023`, or
`-glatest`. IEEE 1800-2017 and IEEE 1800-2023 are first-class conformance
targets. Implemented edition-sensitive constructs are gated by the selected
mode and require positive edition tests plus earlier-edition rejection tests,
but selecting an edition does **not** claim that edition is fully implemented.
See the
[IEEE 1800-2017 clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md)
and [IEEE 1800-2023 survey](docs/conformance/ieee1800_2023_delta.md) for the
measured status and known gaps.

- **Upstream:** [steveicarus/iverilog](https://github.com/steveicarus/iverilog) — the original project
- **This fork:** [dsellerbrock/iverilog-uvm](https://github.com/dsellerbrock/iverilog-uvm)
- **Status:** experimental, under active development. Not reviewed by
  upstream; do **not** use it for production or tapeout work. For anything
  where correctness matters, use official Icarus Verilog.

> **This project is largely AI-written.** The bulk of the SystemVerilog/UVM
> work in this fork was developed by AI (Anthropic's Claude) working against
> the IEEE 1800 standard and the regression suites, with human direction and
> review. The suites are extensive and honesty-focused (loud failures, no
> silent-pass scoring, adversarial audits), but AI-generated compiler code
> carries real risk of plausible-looking-but-wrong behavior. Treat every
> result as guilty until proven innocent, and verify independently before
> relying on it.

The project's ordered goals are to implement both selected IEEE 1800 editions
systematically; run unmodified UVM, OpenTitan, and Caliptra workloads; provide
practical source/runtime/DPI/VPI interoperability with VCS, Questa, and Xcelium
where their behavior agrees with IEEE; and build a standards-correct,
formal-ready frontend and SVA/IR foundation for a future proof engine. Slang is
used as a parser/elaboration differential. Verilator is a diagnostic
cross-check, not the language or runtime oracle. A proof engine is future work,
and UPF/IEEE 1801 is deliberately deferred until the IEEE 1800 frontend is
substantially closed.

The [manifesto](docs/conformance/iverilog_ieee1800_uvm_manifesto.md) governs
that direction. The clause matrix and
[CURRENT_WORK](docs/conformance/CURRENT_WORK.md) contain measured status; an
application passing is evidence, never a full-edition conformance claim.

## What this fork adds

On top of upstream Icarus Verilog's Verilog/partial-SystemVerilog support:

- **UVM**: the unmodified Accellera UVM Core compiles and runs — factory,
  config-db, phasing/objections, sequences, TLM, analysis ports, resource db,
  register layer (frontdoor)
- **Classes**: parameterized classes, virtual dispatch, `$cast`, static
  members, typed method-chain dispatch
- **Constrained randomization**: `rand`/`randc`, constraint blocks, `inside`,
  `dist`, `soft`, implication, `solve...before`, inline `with`, via a Z3 SMT
  backend
- **Containers**: queues, dynamic and associative arrays with the clause-7
  method set (locator/ordering/reduction methods, streaming)
- **Interfaces**: modports, virtual interfaces as class properties (the UVM
  pattern), interface tasks through vif handles
- **Clocking blocks**: sampled input semantics, output drives, `##N`, global
  clocking
- **SVA**: a real concurrent-assertion engine (implication, delay/repetition
  windows, `disable iff`, sampled-value functions, sequence algebra,
  `cover property`)
- **DPI-C**: `import "DPI-C"` with libffi-exact marshaling, open arrays
  (including multidimensional fixed arrays and fixed array members of
  structs), wide vectors, time-consuming exports, the clause-35.9 disable
  cleanup protocol, and shared-library loading via `vvp -d`
- **Functional coverage**: a substantial clause-19 subset including value,
  transition and cross bins, options, queries, and typed per-instance
  constructor-dependent integral ranges; known semantic gaps remain explicit
- **VPI**: SystemVerilog object model — class variables/members, containers,
  interfaces, packages, covergroup and assertion handles, callbacks
- **`bind`**, **`let`**, specify-path and timing-check support (`-gspecify`)

See [Feature support status](#feature-support-status) below for honest
per-area labels — several of these areas have recorded corners.

## Quick start

### Dependencies

Required: GNU make, a C++11 compiler, `bison` ≥ 3.0, `flex`, `gperf` ≥ 3.0,
`autoconf` (building from git), **libz3** (constraint solver), **libffi**
(DPI marshaling). z3 and libffi are hard requirements of this fork's `vvp`
build. Optional: `readline` (interactive debugger), `python3-sphinx` (docs).

```bash
# Ubuntu/Debian
sudo apt install -y make g++ autoconf gperf bison flex libz3-dev libffi-dev libreadline-dev

# macOS (Homebrew)
brew install autoconf gperf bison flex z3 libffi
export PATH="$(brew --prefix bison)/bin:$PATH"
```

### Build

```bash
git clone https://github.com/dsellerbrock/iverilog-uvm.git
cd iverilog-uvm
git submodule update --init          # pulls uvm-core/ (Accellera UVM)
sh autoconf.sh
./configure --prefix="$PWD/install"
make -j"$(nproc)"
make install
export PATH="$PWD/install/bin:$PATH"
```

CI additionally configures `--enable-libveriuser` for legacy PLI support
(see [.github/workflows/test.yml](.github/workflows/test.yml)).

### Running plain SystemVerilog

Select the intended IEEE edition explicitly for SystemVerilog input:

```bash
iverilog -g2017 -o hello.vvp hello.sv    # or -g2023
vvp hello.vvp                            # simulate
```

Use `-I <dir>` for include paths, `-o` to name the output, and `-s <module>`
to pick the top module when there is more than one candidate.

### Running a UVM testbench

Pass `-uvm` and the toolchain wires up UVM for you — the bundled UVM
sources, the correct include path and compile order, and the standard UVM
DPI runtime rather than the `UVM_NO_DPI` fallback:

```bash
iverilog -g2017 -uvm -s top -o sim.vvp my_testbench.sv
vvp sim.vvp +UVM_TESTNAME=my_test
```

No UVM source paths, no `uvm_pkg.sv` on the command line, no `-M`/`-m`/`-d`
shared-library arguments. (Options precede the source files, as `iverilog`
always expects.) The DPI layer (regex name matching, command-line
/ plusarg access, the `uvm_hdl_*` register **backdoor**) is loaded
automatically, and `+UVM_TESTNAME` selects the test when `run_test()` is
called with no argument. This works from any directory and from a relocated
or custom-prefix install.

**Smoke test:** any test in [`tests/`](tests) is a ready-made example:

```bash
iverilog -g2012 -uvm -o smoke.vvp tests/no_rand_test.sv
vvp smoke.vvp
```

which ends with a UVM report summary showing `UVM_ERROR : 0`.

Advanced overrides (a different UVM library, disabling DPI, raw module
loading) are all still available — see **[docs/uvm_frontend.md](docs/uvm_frontend.md)**
for the front-end architecture and **[docs/uvm.md](docs/uvm.md)** for the
UVM usage guide (test selection, plusargs, known UVM-visible limitations).

## Feature highlights

Each area below names its status and points at a regression that shows the
real, working invocation. All `tests/*.sv` compile with the canonical UVM
command above (a few need extra flags, declared in
[.github/uvm_test.sh](.github/uvm_test.sh)).

### Constraints and randomization — substantial

```systemverilog
class my_item extends uvm_sequence_item;
  rand bit [7:0] data;
  rand bit [3:0] addr;
  constraint c_data { data inside {[8'd10:8'd50]}; }
  constraint c_addr { addr < 4'd8; }
  ...
endclass
```

`randomize()` (plain, `with {}`, object- and per-field
`rand_mode`/`constraint_mode`, pre/post_randomize, `dist`, `soft`, foreach
constraints) is solved with Z3. `randcase` and the evidenced structured
`randsequence` subset work.
`srandom()`/`get_randstate()`/`set_randstate()` give each object its own
generator. Unpacked-array `rand_mode` supports fixed, dynamic, queue, and
associative elements (including typed associative keys); whole-array setters
control current and subsequently created elements, and queue element state
moves with insert/delete and ordering operations. Fixed unpacked `randc` arrays maintain
an independent cyclic history for each element. Dynamic/queue/associative
`randc` cycle histories remain a recorded clause-18 gap.

The scope form `std::randomize(vars) with {...}` now reaches the same Z3
constraint IR as class randomization in statement, `void'(...)`, and
expression contexts. Supported destinations are simple integral scalar or
packed-vector variables from 1 through 64 bits, including enum variables;
SAT writes the model through ordinary assignment stores, while UNSAT returns
zero and preserves every destination. Selected/container destinations, arrays,
and vectors wider than 64 bits remain loud unsupported forms. Without a
with-clause, `std::randomize(vars)` continues to randomize normally.
Examples: [tests/constraint_test.sv](tests/constraint_test.sv),
[tests/randomize_with_test.sv](tests/randomize_with_test.sv).

### Interfaces, modports, virtual interfaces — substantial

The UVM pattern — `virtual bus_if vif;` as a class property, passed through
`uvm_config_db#(virtual bus_if)::set/get`, with `@(posedge vif.clk)` and
interface task calls `vif.apply_reset()` — works end to end. Examples:
[tests/vif_config_db_test.sv](tests/vif_config_db_test.sv),
[tests/vif_method_test.sv](tests/vif_method_test.sv). Corner: a bare
module-scope `virtual bus_if v;` variable is a syntax error (class-property
form works).

### Clocking blocks — partial

```systemverilog
interface bus_if(input clk);
  logic data; logic ack;
  clocking cb @(posedge clk);
    input  data;
    output ack;
  endclocking
endinterface
```

Input clockvars have real sampled semantics (IEEE 1800-2017 14.13): wait on
`@(bif.cb)` and read `bif.cb.data` for the LRM-defined race-free sample.
Output drives, `##N`, `default clocking`, global clocking, and clocking
through virtual interfaces work. Example: [tests/clocking_test.sv](tests/clocking_test.sv).
Run-time-selected drives, indexed class receivers, whole unpacked clocking
outputs, and the other boundaries recorded in the clause matrix remain loud
gaps.

### SVA — partial (real core engine)

```systemverilog
assert property (@(posedge clk) disable iff (rst) req |-> ##[1:3] ack)
  else $error("ack missed");
```

Concurrent assertions lower to synthesized checkers with correct overlap and
`|=>` next-cycle semantics — not parse-and-drop. The **automaton engine**
(M9-NFA) is the default SVA engine. Supported: implication,
`##N`/`##[m:n]`/`##[m:$]` (including *mid-chain* windows/unbounded),
`[*n]`/`[*m:n]`, goto/nonconsecutive repetition `[->m:n]`/`[=m:n]`,
`not`/`first_match` (including the composed multi-length cut),
`and`/`or`/`intersect`, `throughout`/`within`/`until` family, per-attempt
local sequence variables, `strong`/`weak` sequence properties,
`seq.triggered`/`seq.matched` endpoint methods, multiclocked `@(c1) a |=>
@(c2) b`, sampled-value functions with real histories,
named/parameterized properties and sequences, `cover property`,
`$asserton/$assertoff/$assertkill`, and the procedural `expect` statement
(fixed-length boolean sequences — the process blocks on a single attempt).
The features not yet lowered (broader multiclock concatenation, overlapping
`|->` across clocks, and `expect` of a variable-length/combinator property)
are **loud sorries**, never silent.

The legacy linear engine remains available for one release as an escape
hatch — set `IVL_SVA_LEGACY=1` in the environment at compile time to select
it (it covers the single-clock non-mid-chain subset and loudly sorries the
rest). A dual-run gate ([tests/sva_nfa/run.sh](tests/sva_nfa/run.sh))
compiles each seed test with both engines and diffs the verdict streams
exactly, so the two stay in lockstep where they overlap. Design and status:
[docs/conformance/m9_nfa_design_2026-07-19.md](docs/conformance/m9_nfa_design_2026-07-19.md).
Example:
[tests/m9_sva_engine_test.sv](tests/m9_sva_engine_test.sv); status detail in
the [clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md) (clause 16).

### DPI-C — substantial

```bash
gcc -shared -fPIC -o mylib.so mylib.c
iverilog -g2012 -o sim.vvp tb.sv
vvp -d ./mylib.so sim.vvp          # ./ needed: the path goes to dlopen(3)
```

`import "DPI-C"` functions and tasks with exact libffi marshaling: integer
atoms, scalar bit/logic, shortreal/real/string/chandle, output/inout copy-back, and open
arrays (1-D and multi-dimensional, including whole fixed-array struct members
with declared range preservation and copy-back, `svGetArrElemPtr` and friends),
`svBitVecVal`/`svLogicVecVal` wide vectors, `c_name=` aliasing. Requires
libffi. Imported signed/unsigned byte and short-int returns use their exact C
width, scalar `shortreal` results and input/output/inout formals use C `float`,
and an `svLogic` return preserves the Annex H X/Z encoding. Packed-vector and
aggregate function results are rejected according to H.8.9. Shortreal arrays
remain a loud unsupported boundary rather than being passed as `double*`.

`export "DPI-C"` (C calling SV) works for functions and tasks whose formals
are integer atoms (byte/shortint/int/longint, signed/unsigned), scalar
bit/logic, packed bit/logic vector formals, shortreal, real, chandle, or
string.
Function results support the Annex H.8.9 by-value subset (integer atoms,
scalar bit/logic, shortreal, real, chandle, string, or void); packed-vector and
aggregate results are illegal even though packed-vector formals are supported.
Scalar output/inout directions use the same exact C ABI, packed-vector formals
use `svBitVecVal`/`svLogicVecVal`, and output/inout strings are retained in
simulator-owned storage after an automatic invocation frame is reaped.
iverilog emits a companion
`<out>.dpiexport.c` stub — compile it into your DPI object
(`gcc -shared -fPIC -o mylib.so mylib.c sim.dpiexport.c`) so the exported C
symbols resolve. An export declaration may precede or follow the subroutine
definition (resolved at end of parse). Multi-instance: `svSetScope`
(`svGetScopeFromName("top.u1")`) selects which instance runs, and a
`context` import that omits `svSetScope` runs the export in its own instance
(35.5.2). **Time-consuming exported tasks** — one that blocks on
`#delay`/`@event` — park the imported task's C stack while simulation time
advances, using POSIX `<ucontext.h>` on Linux/macOS and Win32 Fibers on
MinGW/Windows. Exported task stubs use the Annex H.8.2 C signature
`int task_name(...)`: the status is 0 after normal completion or when the
exported task itself is disabled, and 1 when an enclosing mixed-language call
chain is disabled. In the latter case the blocked C stack is resumed exactly
once so it can call `svIsDisabledState()`, release its resources, and return 1
from the imported task. A disabled imported function performs the same query
and calls `svAckDisabledState()` before returning. Statements after the
disabled export/import do not run; the directly-disabled-export special case
leaves C in the normal state and C continues.

Newly compiled imported tasks use the checked `%dpi/call/task/ack` integer
ABI. The runtime retains the old `%dpi/call/task` void ABI so existing normal
VVP images still load; an old image that is actually disabled fails loudly
because a void call cannot acknowledge that state. Returning the wrong task
status, omitting a function acknowledgment, or calling another export after
the import enters the disabled state is a fatal clause-35.9 protocol error.
The interoperability target for this ABI is IEEE 1800-2017/2023 as implemented
by VCS, Questa, and Xcelium; Verilator is not used as the DPI ABI oracle.

Still loud (never a silent miscompile):
out-of-scope export, `svScope` selection through deep generate/begin
nesting, and the legal fixed-size unpacked-array export-formal ABI, which is
not yet implemented. Exported open-array formals are rejected as illegal by
35.5.6.1/H.8.2; class-handle formals are outside the permitted set in 35.5.6
(pass an opaque foreign object as `chandle`). Imported shortreal arrays also
remain a loud legal gap.
This is what lets the UVM suite run without `UVM_NO_DPI` (see
[uvm_dpi/](uvm_dpi)). Example pairs:
[tests/dpi_basic_test.sv](tests/dpi_basic_test.sv) (import) and
[tests/m10c_dpi_export_test.sv](tests/m10c_dpi_export_test.sv) /
[tests/m10c_dpi_export_test.c](tests/m10c_dpi_export_test.c) (export). The
positive disable/cleanup source—including concurrent-call isolation, an
outstanding branch that survived `join_any`, and disable during C re-entry
immediately after a parked export resumes, plus caller-specific automatic-local
VPI writes from resumed C—is
[tests/m10l_dpi_disable_protocol_test.sv](tests/m10l_dpi_disable_protocol_test.sv).
Its ABI runner is
[tests/vvp_runtime/run_dpi_disable_protocol.sh](tests/vvp_runtime/run_dpi_disable_protocol.sh);
the expected-fatal and legacy-image runners are
[tests/vvp_runtime/run_dpi_disable_protocol_negatives.sh](tests/vvp_runtime/run_dpi_disable_protocol_negatives.sh)
and
[tests/vvp_runtime/run_dpi_legacy_task_void_compat.sh](tests/vvp_runtime/run_dpi_legacy_task_void_compat.sh).

### Functional coverage — partial

```systemverilog
covergroup cg;
  coverpoint data { bins low = {[0:127]}; bins high = {[128:255]}; }
endgroup
```

The evidenced subset includes value/range/default/ignore/illegal bins, compact
transitions, crosses with `binsof`/`intersect`, `iff` guards, instance and type
options, coverage queries, and durable reports.

Typed constructor-dependent integral ranges are captured once per covergroup
object. The bounded expression grammar preserves width, signedness, X/Z
rejection, coverpoint-domain resolution, descending-range emptiness, and the
ordered source-occurrence stream used by fixed bin arrays. It includes
OpenTitan's exact TL agent form
`[0 : 2 << (valid_source_width - 1) - 1]`.

A direct IEEE 1800-2017/2023 audit and paired regressions now establish the
bounded array-bin topology used by dynamic crosses. An integral open array bin
(`bins b[]`) has one logical bin per distinct resolved value, so duplicate and
overlapping ranges coalesce and use value-derived names. A fixed array
(`bins b[N]`) partitions ordered matching occurrences, gives the final
nonempty bin the remainder, and removes ignore/illegal values only after
distribution without redistribution. Per-covergroup-object cross plans now
combine fixed, transition, and constructor-dependent logical source bins;
automatic products, the evidenced `binsof`/`intersect` conjunctions and named-bin
selections, overlapping named bins, `iff`, and declaration-order-independent
`illegal` over `ignore` over normal routing are checked at runtime. An illegal
cross bin does not suppress its source coverpoints or unrelated crosses.
Paired `-g2017`/`-g2023` focus gates pass **20/20** in both the legacy and
JSON/VVP harnesses. IEEE 1800-2023 `option.cross_retain_auto_bins` defaults to
1; a covergroup-level value is the default for its crosses and a cross-local
value overrides it. It is not a coverpoint option or any `type_option`, and the
same declaration is rejected in 2017 mode. The implemented subset evaluates
constant option values only. Its runtime treats any explicit normal,
`ignore_bins`, or `illegal_bins` cross record as explicit even when the
selection is empty. The focused retention reducer pins ordinary-bin and
no-explicit-bin cases, inherited covergroup defaults on fixed and dynamic
crosses, cross-local disable and enable overrides, and empty `ignore_bins` and
`illegal_bins` presence semantics.

Clause 19 remains **PARTIAL**. Constructor `ref`/direction semantics, broader
endpoint expressions, constructor/per-instance expressions for
`cross_retain_auto_bins`, transition-term illegal cross bins, and remaining
dynamic `with`, `matches`, set-expression, `CrossQueueType`, and broader
compound-selection forms are explicit gaps. Source ignore/illegal values are
not yet carved from dynamic-family denominators. Type-coverage union,
report/VPI and normative naming detail, real/tolerance coverage, and products
beyond the explicit 65,536-bin topology cap also remain open. Examples:
[tests/coverage_full_test.sv](tests/coverage_full_test.sv),
[tests/coverage_cross_test.sv](tests/coverage_cross_test.sv), and
[ivtest/ivltests/sv_covergroup_ctor_bin_ranges.v](ivtest/ivltests/sv_covergroup_ctor_bin_ranges.v).

The current native-ARM64 local gates are clean: the paired focus passes
**20/20** in both paths; legacy ivtest reports **4,103 pass / 0 fail / 2 NI /
3 expected fail** (**4,108 total**); JSON/VVP passes **993/993**; negative
diagnostics pass **136/136**; bundled VPI passes **103/103**; and the canonical
unmodified real-DPI UVM suite passes **354/354**. The JSON total includes the
two optional `-tfpga` entries after the native-ARM64 `tgt-fpga` target is built
and installed. Exact design, historical timing, evidence, and invocation detail
is in the
[dynamic-cross session log](docs/conformance/session_logs/2026-08-26_opentitan_dynamic_cross_topology.md).

### VPI — substantial

Existing Icarus VPI flows (`iverilog-vpi`, `vvp -M/-m`) still work. On top,
the fork models SystemVerilog objects through VPI: typed class variables
with value-change callbacks, dynamic arrays/queues/associative arrays with
element access, live runtime-container class properties, class member
navigation, interfaces/modports/packages as scopes, live covergroup
handles, and assertion handles with lifecycle callbacks. Tests live in
`ivtest/vpi/` (`m12_*`, `m12b_*`). Remaining documented corners include
whole-container class-property writes and detailed assertion
sub-expression/variable-latency attempt attribution.

### bind — partial

```systemverilog
bind dut_module checker_module #(.GAIN(2)) chk (.clk(clk), .v(internal_sig));
```

Bind by module/type name works, including parameter overrides, connections
to target-internal signals, bind into interfaces, and bound SVA checkers.
Bind to a *specific instance path* (`bind top.u1.u2 chk c (...)`) and
comma-separated instance lists also work; a nonexistent instance path is a
loud elaboration error. Examples: [tests/m13_bind_test.sv](tests/m13_bind_test.sv),
[tests/m13b_bind_instance_test.sv](tests/m13b_bind_instance_test.sv).

### let — supported

```systemverilog
let max2(x, y) = (x > y) ? x : y;
let scaled(v, f = 2) = v * f;
```

Real expression-macro substitution with default/named arguments, nested
lets, and use in both continuous and procedural contexts. Example:
[tests/m13_let_test.sv](tests/m13_let_test.sv).

### Specify blocks and timing checks — substantial

Compile with **`-gspecify`** to activate specify blocks (otherwise they are
parsed and ignored, matching upstream). Module path delays (`=>`/`*>`),
edge-sensitive and state-dependent paths, `specparam`, and real violation
checkers for `$setup/$hold/$setuphold/$recovery/$removal/$recrem/$skew/
$timeskew/$fullskew/$period/$width/$nochange` (including edge-descriptor
event specs like `posedge clk [01, 0x]`). `$sdf_annotate` applies IOPATH
delays. Examples:
[tests/m13_timing_test.sv](tests/m13_timing_test.sv),
[tests/m13_specify_paths_test.sv](tests/m13_specify_paths_test.sv)
(both compiled with `-gspecify`).

## Feature support status

Labels: **Supported** (works within stated scope), **Substantial** (core
solid, recorded corners), **Partial** (real subset, significant gaps).
Every row is grounded in the paired
[IEEE 1800-2017 clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md)
and [IEEE 1800-2023 survey](docs/conformance/ieee1800_2023_delta.md). Read them
for recorded evidence and known corners, not a completeness certificate.

| Area | Status | Notes |
|---|---|---|
| Core classes / OOP (cl. 8) | Substantial | Interface classes, nested class declarations, module/package/compilation-unit out-of-body `extern` methods, multiple `extends`/`implements` relationships, specialization-aware casts, inherited type visibility and method-contract checks are supported |
| UVM (Accellera core, unmodified) | Substantial | Current local canonical checkpoint: 354/354, 0 failed, 0 skipped, run WITHOUT `UVM_NO_DPI` via the Icarus UVM DPI backend (regex + command-line + `uvm_hdl_*` backdoor); frontdoor + user-defined backdoor work; `UVM_NO_DPI` native fallback still supported. |
| Constraints / randomization (cl. 18) | Substantial | Z3-backed, including scope `std::randomize(vars) with {...}` for simple 1–64-bit integral variables; `randcase`/`randsequence` work |
| Containers (queues/darrays/assoc, cl. 7) | Substantial | Broad recorded method subset; explicit receiver, typing, and context gaps remain |
| Interfaces / virtual interfaces (cl. 25) | Substantial | UVM vif pattern end-to-end; bare module-scope `virtual` var missing |
| Clocking blocks (cl. 14) | Partial | Sampled inputs, common output drives, `##N`, and global clocking work; recorded run-time-selected, indexed-receiver, and aggregate-output gaps remain |
| Scheduler / event regions (cl. 4) | Supported | Full stratified queue incl. Preponed, post-NBA (`cbNBASynch`), Observed and the Reactive set; assertions sample Preponed, evaluate in Observed and run their actions in Reactive; region tracing/self-test under `IVL_REGION_TRACE` / `IVL_REGION_SELFTEST` ([audit](docs/conformance/scheduler_audit_2026_07.md)) |
| SVA (cl. 16) | Partial | Automaton (NFA) engine is the default: implication, windows/unbounded incl. mid-chain, goto/nonconsec repetition, local vars, first_match, and/or/intersect/within/throughout, strong/weak, `.triggered`/`.matched`, multiclocked `\|=>`; legacy linear engine behind `IVL_SVA_LEGACY=1`; `expect` and `checker`/`endchecker` implemented; remaining loud boundaries include cross-clock overlapping `\|->`, `disable iff` across a two-or-more-boundary chain, and the separately recorded branch-flow/deferred-immediate gaps |
| Functional coverage (cl. 19) | Partial | Substantial value/transition/cross/options/query subset. Paired legacy and JSON/VVP focus gates pass 20/20 for typed construction-time ranges, open/fixed array-bin identity and carving, per-instance dynamic cross topology, automatic and evidenced named-`binsof` routing, precedence/locality, and the constant 2023 auto-retention option. The constant option obeys the covergroup-default/cross-override scope and 2017 edition gate; coverpoint and `type_option` placements are rejected. Constructor/per-instance retention expressions, transition-term illegal crosses, remaining dynamic `with`/`matches`/set/`CrossQueueType` and broader compound selections, source denominator carving, type/report/VPI/naming, real/tolerance, and products beyond 65,536 remain open. |
| DPI-C (cl. 35) | Substantial | Import: exact scalar/atom/shortreal ABI and open arrays incl. multi-dim. Export: functions plus task execution with integer/scalar bit-logic/packed-vector/shortreal/real/chandle/string/void formals, scalar output/inout, `svScope` multi-instance + context-relative selection, and time-consuming tasks through POSIX `<ucontext.h>` or Win32 Fibers; generated task stubs return the H.8.2 `int` disable status. Checked imported-task integer acknowledgments, `svIsDisabledState`, imported-function `svAckDisabledState`, C cleanup resume, and fatal enforcement of 35.9(b)–(d) are implemented; old `%dpi/call/task` void images retain their normal-call compatibility path. Identical cross-scope/multi-instance exports remain legal, while duplicate local linkage names and incompatible cross-scope C signatures are rejected. H.8.9 keeps packed-vector results illegal. Loud legal gaps: imported shortreal arrays and fixed-size unpacked export formals. Exported open arrays and class-handle formals are diagnosed as IEEE-illegal. VCS/Questa/Xcelium interoperability remains the ABI target. |
| VPI SV object model (cl. 36) | Substantial | Classes, live direct/property containers and element callbacks, covergroups, assertions; documented whole-container-write and assertion-detail corners remain |
| `bind` (cl. 23.11) | Substantial | Module/type, instance-path, and instance-list targets |
| `let` (cl. 11.13) | Supported | Expression-macro semantics |
| Specify / timing checks (cl. 30–31) | Substantial | Recorded timing-check family under `-gspecify`, including `$timeskew`, `$fullskew`, and `$nochange`; exhaustive forms and interactions remain open |

### Application-corpus checkpoint

The current local canonical unmodified Accellera UVM checkpoint passes
**354/354** with real DPI. Application compatibility is less complete:

- The final native-ARM64 OpenTitan 61-target UVM **compile** matrix at clean
  revision `7a3ad34b` is **8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS**, versus
  **1 DEBT / 57 FAIL / 3 SETUP_FAIL / 0 PASS** before this increment. Seven targets moved from FAIL to
  DEBT (`adc_ctrl`, `dma`, `hmac`, `mbx`, `pattgen`, `soc_dbg_ctrl`, and
  `uart`), while `tl_agent` remains DEBT. Both the exact former constructor-
  dependent-cross-drop diagnostic and the generic cross-drop diagnostic occur
  zero times. The run had zero timeouts or resource-limit signals. Remaining
  parser, provider, clocking, dynamic-`with`, and isolated elaboration failures
  still prevent a clean application pass. This was a compile matrix and did
  not run simulations.
- The final frozen Caliptra static census completes all 105 jobs and 420
  compiler invocations: Icarus is **53/105** in each assertions,
  no-assertions, and synthesis lane versus Slang **54/105**. Its classifications
  are **52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG /
  1 SOURCE_ORDER_DEBT / 0 ICARUS_GAP**; the sole Slang advantage is the known
  `csrng_raw_wrap` source-order debt. This is compile/elaboration/synthesis
  differential evidence, not full Caliptra DV runtime, which still requires
  external verification inputs.

Exact revisions, commands, classifications, and newer results belong in
[CURRENT_WORK](docs/conformance/CURRENT_WORK.md), not in a rounded compatibility
percentage.

## Known limitations

- **Experimental.** AI-assisted development, not upstream-reviewed. Verify
  results independently before relying on them.
- `export "DPI-C"` supports functions and tasks with integer atoms, scalar
  bit/logic, packed bit/logic vector formals, shortreal, real, chandle, string,
  and void ABI forms (packed-vector function results remain illegal under H.8.9),
  `svScope` multi-instance + context-relative selection, and
  time-consuming exported tasks through POSIX `<ucontext.h>` on Linux/macOS
  or Win32 Fibers on MinGW/Windows, which park the C stack across time.
  The legal fixed-size unpacked-array export ABI remains unimplemented but
  loud; exported open arrays and class-handle formals are rejected as illegal
  by 35.5.6/35.5.6.1/H.8.2. Imported shortreal arrays are also loud until
  float-array copy marshaling is implemented. The 35.9/H.8.2 disable protocol
  itself is implemented and checked; only the retained legacy
  `%dpi/call/task` void-image path cannot acknowledge a disable and therefore
  reports one loudly. UVM's `uvm_hdl_*` register **backdoor** works via the
  Icarus UVM DPI backend ([`uvm_dpi/`](uvm_dpi)), which `-uvm` installs and
  loads automatically; `--uvm-no-dpi` remains available to skip DPI.
- Recursive `randsequence` grammars, nonconstant production-actual capture,
  value-returning productions, and nested-control `rand join` lanes are
  rejected with explicit diagnostics. `wait_order` remains unsupported.
- Vendored ivtest totals evolve as tests are added. Current pass/fail/NI/EF
  counts and exact tool provenance are recorded in
  [CURRENT_WORK](docs/conformance/CURRENT_WORK.md); dated historical baselines
  are retained for comparison rather than presented here as current totals.
- The project's standing rule: unsupported constructs must fail **loudly**
  (error/sorry/warning), never silently miscompile. Suspected silent
  miscompiles are the highest-priority bug class — please report them.

Deeper status: [clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md) ·
[milestone truth audit](docs/conformance/milestone_truth_audit_2026-07-16.md) ·
[CURRENT_WORK](docs/conformance/CURRENT_WORK.md) ·
[issue tracker](https://github.com/dsellerbrock/iverilog-uvm/issues)

## Testing

With `install/bin` on `PATH`, from the repository root:

```bash
./.github/uvm_test.sh                    # UVM sweep: every tests/*.sv case
bash tests/negative/run_negative.sh      # negative tests: must FAIL loudly
./.github/test.sh                        # full ivtest + VPI regression
bash tests/sva_nfa/run.sh                # SVA dual-run gate (legacy vs NFA engine)
```

`./.github/test.sh` is the integrated ivtest/VPI gate; it expands to
`cd ivtest && perl vvp_reg.pl && perl vpi_reg.pl --with-pli1 && python3 vvp_reg.py`.
Compare its exact results against [CURRENT_WORK](docs/conformance/CURRENT_WORK.md)
and the corresponding dated session log rather than a frozen README total.
`make check` runs the compiler's own self-test. The UVM sweep scores by
explicit evidence: a test with no PASS marker and no error output counts as
a failure, and known limitations are skipped with a stated reason. The
[test-suite audit](docs/conformance/test_suite_audit_2026-07-17.md) documents
each harness's integrity and every standing failure.

## Contributing

Workflow expectations (the
[manifesto](docs/conformance/iverilog_ieee1800_uvm_manifesto.md) is the full
version; the PR template walks you through them):

1. **Reduce** bugs to a minimal pure-SystemVerilog reproducer — especially
   bugs found via UVM. Fix the simulator, never patch the UVM library.
2. **Cite the IEEE 1800 clause** your change implements or fixes.
3. **Add regressions**: the reduced reproducer as a positive test in
   `tests/`, plus negative tests in `tests/negative/` where illegal input
   should be rejected.
4. **No UVM-specific hacks** in the compiler — fix the shared architecture,
   not the identifier.
5. **No silent fallbacks**: unsupported paths must produce a loud
   error/sorry/warning.
6. **Run the suites** (focused tests, UVM sweep, negative suite; ivtest for
   compiler-core changes) and compare against the recorded baselines.
7. **Document honestly**: partial support is fine, undocumented partial
   support is not. Update the clause matrix / CURRENT_WORK when status
   changes.
8. **AI assistance is welcome** — much of this fork was built that way. It
   changes nothing about the bar: all code is vetted the same regardless of
   origin (reduced reproducer, clause citation, positive and negative
   regressions, suite runs, honest status). You are responsible for
   understanding and standing behind what you submit.

**Bug reports:** file a [GitHub issue](https://github.com/dsellerbrock/iverilog-uvm/issues)
with the minimal `.sv` reproducer, the exact command line, and
expected-vs-actual output. Silent-wrong-answer cases are the most valuable
reports.

## Documentation index

**Start here**
- [UVM usage guide](docs/uvm.md) — compile/run UVM, DPI on/off, limitations
- [IEEE 1800-2017 clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md) — per-clause conformance disposition
- [IEEE 1800-2023 survey](docs/conformance/ieee1800_2023_delta.md) — first-class 2023 edition audit and deltas
- [Manifesto](docs/conformance/iverilog_ieee1800_uvm_manifesto.md) — governing principles and architecture direction

**Current status and plans**
- [CURRENT_WORK](docs/conformance/CURRENT_WORK.md) — running status checkpoint
- [Roadmap](docs/conformance/ROADMAP.md) — canonical execution tracker
- [Frontier roadmap](docs/conformance/frontier_roadmap_2026-07-17.md) — dated 2026-07-17 historical snapshot
- [Milestone truth audit](docs/conformance/milestone_truth_audit_2026-07-16.md) — dated 2026-07-16 historical audit
- [Test-suite audit](docs/conformance/test_suite_audit_2026-07-17.md) — harness integrity, failure dispositions
- [ivtest baseline](docs/conformance/ivtest_vendored_baseline_2026-07-18.txt) — recorded pass/fail set vs. upstream

**Architecture and internals**
- [Scheduler audit](docs/conformance/scheduler_audit_2026_07.md) and [scheduler conformance inventory](docs/conformance/scheduler_conformance_inventory.md)
- [M6 call re-architecture](docs/conformance/m6_callf_rearchitecture.md) / [scheduled-call protocol](docs/conformance/m6_scheduled_call_protocol.md)
- [Documentation/](Documentation) — upstream Icarus developer/usage docs (Sphinx; compiler pipeline, targets, VPI)

**History**
- [Session logs](docs/conformance/session_logs) — dated per-increment engineering logs
- [Phase-era README](docs/history/2026-05_phase_history_readme.md) — spring-2026 phase notes, OpenTitan UART DV bring-up
- [CHANGES.md](CHANGES.md) — phase-era technical design document
- [Gap audit](docs/claude/uvm_ieee1800_gap_audit_2026_05.md) / [gap plan](docs/claude/uvm_gap_plan.md) / [phase proposal](PHASE_PROPOSAL.md) — earlier planning documents

## Relationship with upstream

This is a fork of [steveicarus/iverilog](https://github.com/steveicarus/iverilog);
Icarus Verilog is Stephen Williams' project and the upstream of record. The
work here is experimental and expansive; upstreaming pieces as minimal,
reviewable patches is a long-term goal (see
[CHANGES.md §11](CHANGES.md)), but **no assumption should be made that any
of it has been accepted upstream**. Nothing here implies upstream endorsement.

Please don't burden the upstream project with this fork:

- **Report bugs in this fork [here](https://github.com/dsellerbrock/iverilog-uvm/issues),
  never on the upstream tracker**, unless you have reproduced them on
  official Icarus Verilog.
- Anything proposed for mainline must first be decomposed into small,
  single-purpose patches and pass a **thorough, independent correctness
  review** — the largely AI-written history here means upstream maintainers
  would be right to demand a higher, not lower, standard of evidence. That
  review has not happened yet, and **some or all of this work may never be
  accepted upstream**. That is upstream's call to make, at their pace.

## Credits and license

Icarus Verilog is Copyright © Stephen Williams (2000–2026), GPL-2.0+ — see
[COPYING](COPYING). SystemVerilog/UVM fork maintained by Daniel Ellerbrock;
the fork's code is largely AI-written (Claude, Anthropic) under human
direction and review.
[Accellera UVM Core](https://github.com/accellera-official/uvm-core) is
Copyright Accellera Systems Initiative, Apache-2.0.
