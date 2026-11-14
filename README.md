# Icarus Verilog — SystemVerilog / UVM fork

[![CI](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml)

An experimental fork of
[Icarus Verilog](https://github.com/steveicarus/iverilog) that adds
SystemVerilog and runs the unmodified
[Accellera UVM](https://github.com/accellera-official/uvm-core) library. It aims
at IEEE 1800-2017/2023, UVM compatibility, and real OpenTitan and Caliptra
verification workloads.

> **Experimental and largely AI-written, with human direction and review.** This
> fork has not been reviewed or endorsed by upstream. Do not use it for
> production or tapeout work; independently verify simulation results.

## Status

**What works**, each as a working subset with known gaps:

- **UVM:** factory, configuration, phasing, sequences, TLM and register access,
  with automatic UVM source and DPI loading.
- **SystemVerilog:** classes, constrained randomization (using Z3), queues,
  dynamic and associative arrays, interfaces and virtual interfaces.
- **Verification:** concurrent assertions (SVA), clocking blocks, functional
  coverage, `bind`, and specify/timing checks.
- **C integration:** DPI-C imports and exports, and an expanded SystemVerilog
  VPI object model.
- **Workloads:** the selected OpenTitan runtime gate passes 49/49 targets; the
  wider compile census does not yet
  ([OpenTitan status](docs/conformance/opentitan_status.md)).

**What doesn't, yet:**

- **Standards support is incomplete.** Every area above still has unsupported
  forms; clocking blocks, mailboxes, SVA, coverage and `bind` have significant
  gaps, and `wait_order`, recursive or value-returning `randsequence`
  productions, imported DPI shortreal arrays and fixed-size unpacked DPI export
  formals are unsupported. The
  [2017 clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md)
  and [2023 survey](docs/conformance/ieee1800_2023_delta.md) define the tested
  scope; [BLOCKERS](docs/conformance/BLOCKERS.md) lists what remains.
- **A workload pass is not full support.** Passing UVM or OpenTitan runs do not
  establish full IEEE 1800.2 or OpenTitan/Caliptra DV support, and a compile
  alone proves no traffic or checking.
  [CURRENT_WORK](docs/conformance/CURRENT_WORK.md) has the latest evidence, and
  the [release overlays](docs/conformance/release_overlays/README.md) the pinned
  application sources and patches. Historical `DEBT` results are not passes.
- **No formal proof engine.** SVA executes during simulation; Z3 serves
  randomization only. UPF/IEEE 1801 is deferred.

Unsupported behavior must produce a diagnostic, never a silently different
result, and a warning does not make a result correct. Please
[report](#contributing) suspected silent wrong answers as bugs.

## Quick start

GNU make, a C++11 compiler, autoconf, Bison ≥ 3.0, Flex and gperf ≥ 3.0 are
needed, and **Z3 and libffi are required** even without UVM. Readline is
optional.

```bash
# Ubuntu/Debian
sudo apt install -y make g++ autoconf gperf bison flex libz3-dev libffi-dev libreadline-dev

# macOS (Homebrew; also install Xcode Command Line Tools)
brew install autoconf gperf bison flex z3 libffi
export PATH="$(brew --prefix bison)/bin:$PATH"
export CPPFLAGS="-I$(brew --prefix libffi)/include -I$(brew --prefix z3)/include"
export LDFLAGS="-L$(brew --prefix libffi)/lib -L$(brew --prefix z3)/lib"
```

Build and install. Initialize the UVM submodule first, so the compiler records
its version:

```bash
git clone https://github.com/dsellerbrock/iverilog-uvm.git
cd iverilog-uvm
git submodule update --init uvm-core
sh autoconf.sh
./configure --prefix="$PWD/install" --enable-libveriuser   # legacy PLI, used by the tests
make
make install          # also installs the bundled UVM and its DPI backend
export PATH="$PWD/install/bin:$PATH"
```

If the UVM DPI build fails, `make install` warns and falls back to `UVM_NO_DPI`,
which is not equivalent, so check its output.

### Run SystemVerilog

```bash
iverilog -g2017 -s top -o sim.vvp my_testbench.sv
vvp sim.vvp
```

### Run UVM

`-uvm` compiles with the bundled library and loads its DPI backend, including
register backdoor access; no UVM paths or library flags are needed.
`+UVM_TESTNAME` selects the test when the testbench calls `run_test()` with no
argument.

```bash
iverilog -g2017 -uvm -s top -o sim.vvp my_testbench.sv
vvp sim.vvp +UVM_TESTNAME=my_test
iverilog -g2012 -uvm -o smoke.vvp tests/no_rand_test.sv && vvp smoke.vvp   # smoke test
```

The [UVM guide](docs/uvm.md) covers test selection, plusargs, DPI choices and
troubleshooting.

## Common options

| Option | Meaning |
| --- | --- |
| `-s TOP`, `-I DIR` | The top-level module; an include directory. |
| `-g2012`, `-g2017`, `-g2023`, `-glatest` | The language edition. Selecting one does **not** mean it is fully implemented ([edition gates](docs/conformance/language_edition_gates.md)). |
| `-gspecify` | Specify blocks and timing checks (off by default). |
| `-uvm` | Compile with the bundled UVM library and load its DPI backend. |
| `--uvm=RELEASE` | Use another UVM release, registered with [`scripts/uvm_release_matrix.py`](scripts/uvm_release_matrix.py); registering it does not establish compatibility ([release matrix](docs/conformance/uvm_release_matrix.md)). |
| `--uvm-home=DIR` | Use the UVM source tree at DIR (or `$IVERILOG_UVM_HOME`). |
| `--uvm-no-dpi` | UVM's pure-SystemVerilog fallbacks instead of its DPI backend. More in the [UVM frontend](docs/uvm_frontend.md) guide. |
| `-gcommercial-unsafe` | Narrow, nonstandard relaxations for code written against commercial simulators; not IEEE conformance ([compatibility options](docs/compatibility_options.md)). |

Developer trace switches (`IVL_*_TRACE`) are in
[debug_env.md](docs/debug_env.md).

## Documentation

The [documentation index](docs/README.md) maps every topic to the document that
owns it: usage guides, current status
([CURRENT_WORK](docs/conformance/CURRENT_WORK.md)), goals
([roadmap](docs/conformance/ROADMAP.md)), conformance records and dated
evidence. Upstream's compiler, target and VPI documentation is in
[Documentation/](Documentation).

## Testing

From the repository root, with the compiler just built on `PATH`:

```bash
make check                              # compiler self-test
bash .github/uvm_test.sh                # UVM regression
bash tests/negative/run_negative.sh     # expected-error tests
make -C tgt-fpga install                # a target two ivtest cases need
sh .github/test.sh                      # integrated ivtest + VPI regression
bash tests/sva_nfa/run.sh               # compare the two SVA engines
```

The [test-suite audit](docs/conformance/test_suite_audit_2026-07-17.md) covers
harness prerequisites and failures;
[CURRENT_WORK](docs/conformance/CURRENT_WORK.md) has the baselines to compare
against.

## Contributing

[Report fork bugs here](https://github.com/dsellerbrock/iverilog-uvm/issues)
with a minimal `.sv` reproducer, the exact command, the compiler version, and
expected versus actual output. Use upstream's tracker only if the bug also
reproduces on official Icarus Verilog.

A change cites its IEEE clause, fixes the shared simulator behavior, adds
positive and negative regressions, runs the affected suites and updates the
status docs. Don't patch UVM or add silent fallbacks to make tests pass.
AI-assisted contributions meet the same review and evidence bar. See the
[contribution policy](docs/conformance/iverilog_ieee1800_uvm_manifesto.md), the
[PR template](.github/pull_request_template.md) and, for agents,
[AGENTS.md](AGENTS.md).

## Credits and license

Icarus Verilog is Stephen Williams' project, Copyright © 2000–2026,
[GPL-2.0+](COPYING). This fork is maintained by Daniel Ellerbrock; much of its
SystemVerilog/UVM code was written with Anthropic's Claude under human direction
and review. Upstream acceptance of this work is not implied. Accellera UVM Core
is Copyright Accellera Systems Initiative, Apache-2.0.
