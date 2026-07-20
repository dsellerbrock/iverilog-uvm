# Icarus Verilog — SystemVerilog / UVM fork

[![CI](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml)

An **experimental development fork** of [Icarus Verilog](https://github.com/steveicarus/iverilog)
focused on broad IEEE 1800-2017 SystemVerilog conformance and running the
unmodified [Accellera UVM Core library](https://github.com/accellera-official/uvm-core).

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

The project has two goals, in this order: run real UVM testbenches without
patching the UVM library, and implement IEEE 1800 semantics systematically
enough that support can be measured clause by clause. The
[manifesto](docs/conformance/iverilog_ieee1800_uvm_manifesto.md) is the
governing plan; the
[IEEE 1800-2017 clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md)
is the measured result.

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
- **DPI-C**: `import "DPI-C"` with libffi-exact marshaling, open arrays, wide
  vectors, shared-library loading via `vvp -d`
- **Functional coverage**: covergroups with full clause-19 bin semantics,
  transitions, crosses, options, coverage queries
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

`-g2012` selects IEEE 1800 SystemVerilog mode — required for any SV input:

```bash
iverilog -g2012 -o hello.vvp hello.sv    # compile to VVP bytecode
vvp hello.vvp                            # simulate
```

Use `-I <dir>` for include paths, `-o` to name the output, and `-s <module>`
to pick the top module when there is more than one candidate.

### Running a UVM testbench

```bash
iverilog -g2012 \
  -I uvm-core/src \
  -DUVM_NO_DPI \
  -o sim.vvp \
  uvm-core/src/uvm_pkg.sv \
  my_testbench.sv

vvp sim.vvp +UVM_TESTNAME=my_test
```

`uvm_pkg.sv` must precede your sources; `-DUVM_NO_DPI` selects UVM's
pure-SystemVerilog fallbacks and is the supported configuration (the
`uvm_hdl_*` DPI register-*backdoor* path is the main thing it disables;
user-defined `uvm_reg_backdoor` classes and your own DPI-C code still
work). `+UVM_TESTNAME` selects the test when the testbench calls
`run_test()` with no argument.

**Smoke test:** any test in [`tests/`](tests) is a ready-made example, e.g.

```bash
iverilog -g2012 -I uvm-core/src -DUVM_NO_DPI -o smoke.vvp \
    uvm-core/src/uvm_pkg.sv tests/no_rand_test.sv
vvp smoke.vvp
```

which ends with a UVM report summary showing `UVM_ERROR : 0`. Compiling the
UVM library prints deliberate loud warnings/sorries for recorded corners —
see **[docs/uvm.md](docs/uvm.md)** for the full UVM guide (test selection,
plusargs, DPI-on vs. DPI-off, known UVM-visible limitations).

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

`randomize()` (plain, `with {}`, `rand_mode`/`constraint_mode`,
pre/post_randomize, `dist`, `soft`, foreach constraints) is solved with Z3.
Known gaps: `randcase`/`randsequence` and the scope form
`std::randomize(var)` are loud diagnostics; per-field `obj.f.rand_mode(0)`
freeze is not honored. Examples: [tests/constraint_test.sv](tests/constraint_test.sv),
[tests/randomize_with_test.sv](tests/randomize_with_test.sv).

### Interfaces, modports, virtual interfaces — substantial

The UVM pattern — `virtual bus_if vif;` as a class property, passed through
`uvm_config_db#(virtual bus_if)::set/get`, with `@(posedge vif.clk)` and
interface task calls `vif.apply_reset()` — works end to end. Examples:
[tests/vif_config_db_test.sv](tests/vif_config_db_test.sv),
[tests/vif_method_test.sv](tests/vif_method_test.sv). Corner: a bare
module-scope `virtual bus_if v;` variable is a syntax error (class-property
form works).

### Clocking blocks — supported

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

### SVA — partial (real core engine)

```systemverilog
assert property (@(posedge clk) disable iff (rst) req |-> ##[1:3] ack)
  else $error("ack missed");
```

Concurrent assertions lower to synthesized checkers with correct overlap and
`|=>` next-cycle semantics — not parse-and-drop. Supported: implication,
`##N`/`##[m:n]`/`##[m:$]`, `[*n]`/`[*m:n]`, `not`/`first_match`,
`and`/`or`/`intersect`, `throughout`/`within`/`until` family, sampled-value
functions with real histories, named/parameterized properties and sequences,
`cover property`, `$asserton/$assertoff/$assertkill`. Unsupported operators
(local sequence variables, `.matched`, `expect`, goto repetition, unbounded
liveness) are **loud sorries**, never silent.

An experimental **automaton engine** (M9-NFA) can be opted into with
`IVL_SVA_NFA=1` in the environment at compile time: shapes it covers lower
to NFA slot-pool checkers instead, which adds *mid-chain*
`##[m:n]`/`##[m:$]` support (the default engine sorries there); everything
else falls back to the default engine unchanged. A dual-run gate
([tests/sva_nfa/run.sh](tests/sva_nfa/run.sh)) compiles each seed test with
the flag off and on and diffs the verdict streams exactly. Design and
status: [docs/conformance/m9_nfa_design_2026-07-19.md](docs/conformance/m9_nfa_design_2026-07-19.md).
Example:
[tests/m9_sva_engine_test.sv](tests/m9_sva_engine_test.sv); status detail in
the [clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md) (clause 16).

### DPI-C — substantial

```bash
gcc -shared -fPIC -o mylib.so mylib.c
iverilog -g2012 -o sim.vvp tb.sv
vvp -d ./mylib.so sim.vvp          # ./ needed: the path goes to dlopen(3)
```

`import "DPI-C"` functions and tasks with exact libffi marshaling: int/real/
string/chandle scalars, output/inout copy-back, open arrays (1-D and
multi-dimensional, `svGetArrElemPtr` and friends),
`svBitVecVal`/`svLogicVecVal` wide vectors, `c_name=` aliasing. Requires
libffi. Not supported: `export "DPI-C"` (C calling SV) — a loud diagnostic;
this is also what keeps UVM's `uvm_hdl_*` backdoor unavailable. Example pair:
[tests/dpi_basic_test.sv](tests/dpi_basic_test.sv) /
[tests/dpi_basic_test.c](tests/dpi_basic_test.c).

### Functional coverage — supported

```systemverilog
covergroup cg;
  coverpoint data { bins low = {[0:127]}; bins high = {[128:255]}; }
endgroup
```

Clause-19 bin semantics: value/transition/cross bins, `binsof`/`intersect`,
ignore/illegal/default bins, `iff` guards, options, instance and type
coverage, `$get_coverage`, and a durable end-of-run report. Examples:
[tests/coverage_full_test.sv](tests/coverage_full_test.sv),
[tests/coverage_cross_test.sv](tests/coverage_cross_test.sv).

### VPI — substantial

Existing Icarus VPI flows (`iverilog-vpi`, `vvp -M/-m`) still work. On top,
the fork models SystemVerilog objects through VPI: typed class variables
with value-change callbacks, dynamic arrays/queues/associative arrays with
element access, class member navigation, interfaces/modports/packages as
scopes, live covergroup handles, and assertion handles with
success/failure callbacks. Tests live in `ivtest/vpi/` (`m12_*`, `m12b_*`).
Remaining: force/release on bit-selects, some `cbAssertion*` reasons.

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
Every row is grounded in the empirical
[IEEE 1800-2017 clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md) —
read it for the per-clause evidence and the complete corner ledger.

| Area | Status | Notes |
|---|---|---|
| Core classes / OOP (cl. 8) | Substantial | No interface classes, nested classes, out-of-body `extern` methods |
| UVM (Accellera core, unmodified) | Substantial | 198-test regression green with `UVM_NO_DPI` (zero skips); register frontdoor + user-defined backdoor work, `uvm_hdl_*` DPI backdoor needs DPI export |
| Constraints / randomization (cl. 18) | Substantial | Z3-backed; `randcase`, scope `std::randomize` diagnosed |
| Containers (queues/darrays/assoc, cl. 7) | Substantial | Full method set; narrow recorded corners |
| Interfaces / virtual interfaces (cl. 25) | Substantial | UVM vif pattern end-to-end; bare module-scope `virtual` var missing |
| Clocking blocks (cl. 14) | Supported | Sampled inputs, output drives, `##N`, global clocking |
| Scheduler / event regions (cl. 4) | Partial | Regions modeled; formal region trace still open ([audit](docs/conformance/scheduler_audit_2026_07.md)) |
| SVA (cl. 16) | Partial | Real core engine; opt-in NFA engine (`IVL_SVA_NFA=1`) adds mid-chain window/unbounded shapes; remaining automaton-class features are loud sorries |
| Functional coverage (cl. 19) | Supported | Full clause-19 bin semantics |
| DPI-C (cl. 35) | Substantial | Open arrays incl. multi-dim; no `export "DPI-C"` |
| VPI SV object model (cl. 36) | Substantial | Classes, containers, covergroups, assertions; force/release corners open |
| `bind` (cl. 23.11) | Substantial | Module/type, instance-path, and instance-list targets |
| `let` (cl. 11.13) | Supported | Expression-macro semantics |
| Specify / timing checks (cl. 30–31) | Substantial | With `-gspecify`; full checker set incl. `$timeskew`/`$fullskew`/`$nochange` |

## Known limitations

- **Experimental.** AI-assisted development, not upstream-reviewed. Verify
  results independently before relying on them.
- No `export "DPI-C"` → UVM's `uvm_hdl_*` register **backdoor** path is
  unavailable (frontdoor and user-defined `uvm_reg_backdoor` classes work);
  use `-DUVM_NO_DPI`.
- `randcase`, `randsequence`, `wait_order`, interface classes, `checker`
  blocks: rejected with explicit diagnostics.
- Of the 3101-test upstream `ivtest` suite, 44 tests currently fail (vs. 83
  on pristine upstream at the fork base) — the live expected set is
  [ivtest_expected_fails.list](docs/conformance/ivtest_expected_fails.list);
  the fork-vs-upstream deltas, both directions, are itemized in the
  [ivtest baseline](docs/conformance/ivtest_vendored_baseline_2026-07-18.txt).
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
./.github/uvm_test.sh                    # UVM sweep: all tests/*.sv (198)
bash tests/negative/run_negative.sh      # negative tests: must FAIL loudly
./.github/test.sh                        # full ivtest + VPI regression
bash tests/sva_nfa/run.sh                # SVA dual-run gate (legacy vs NFA engine)
```

`./.github/test.sh` is what CI runs; it expands to
`cd ivtest && perl vvp_reg.pl && perl vpi_reg.pl --with-pli1 && python3 vvp_reg.py`
(the 3101-test vendored upstream suite — compare failures against the
[recorded baseline](docs/conformance/ivtest_vendored_baseline_2026-07-18.txt)).
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
- [Manifesto](docs/conformance/iverilog_ieee1800_uvm_manifesto.md) — governing principles and architecture direction

**Current status and plans**
- [CURRENT_WORK](docs/conformance/CURRENT_WORK.md) — running status checkpoint
- [Frontier roadmap](docs/conformance/frontier_roadmap_2026-07-17.md) — what's next, by tractability
- [Milestone truth audit](docs/conformance/milestone_truth_audit_2026-07-16.md) — honest M0–M14 milestone status
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
