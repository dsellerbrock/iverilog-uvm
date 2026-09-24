# Icarus Verilog — SystemVerilog / UVM fork

[![CI](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/dsellerbrock/iverilog-uvm/actions/workflows/test.yml)

An experimental fork of [Icarus Verilog](https://github.com/steveicarus/iverilog)
adding SystemVerilog and unmodified [Accellera UVM](https://github.com/accellera-official/uvm-core)
support. The targets are IEEE 1800-2017/2023, UVM compatibility, and real
OpenTitan and Caliptra verification workloads.

> **Experimental and largely AI-written, with human direction and review.**
> This fork has not been reviewed or endorsed by upstream. Do not use it for
> production or tapeout work; independently verify simulation results.

## What this fork adds

- **UVM:** factory, configuration, phasing, sequences, TLM, and register access,
  with automatic UVM source and DPI loading.
- **SystemVerilog:** classes, constrained randomization using Z3, queues,
  dynamic/associative arrays, interfaces, and virtual interfaces.
- **Verification:** concurrent assertions (SVA), clocking blocks, functional
  coverage, `bind`, and specify/timing checks.
- **C integration:** DPI-C imports/exports and an expanded SystemVerilog VPI
  object model.

These features have working subsets and known gaps. See
[Known limitations](#known-limitations) before choosing a workload.

## Quick start

### Dependencies

GNU make, a C++11 compiler, autoconf, Bison ≥ 3.0, Flex, and gperf ≥ 3.0.
**Z3 and libffi are required**, including for builds that do not use UVM.
Readline is optional.

```bash
# Ubuntu/Debian
sudo apt install -y make g++ autoconf gperf bison flex libz3-dev libffi-dev libreadline-dev

# macOS (Homebrew; also install Xcode Command Line Tools)
brew install autoconf gperf bison flex z3 libffi
export PATH="$(brew --prefix bison)/bin:$PATH"
export CPPFLAGS="-I$(brew --prefix libffi)/include -I$(brew --prefix z3)/include"
export LDFLAGS="-L$(brew --prefix libffi)/lib -L$(brew --prefix z3)/lib"
```

### Build

Initialize UVM before the first build so the compiler records its version.

```bash
git clone https://github.com/dsellerbrock/iverilog-uvm.git
cd iverilog-uvm
git submodule update --init uvm-core
sh autoconf.sh
./configure --prefix="$PWD/install" --enable-libveriuser
make
make install
export PATH="$PWD/install/bin:$PATH"
```

`make install` also installs bundled UVM and its DPI backend.
`--enable-libveriuser` enables legacy PLI support used by the regression suite.
Check the install output: if the DPI build fails, installation warns and falls
back to `UVM_NO_DPI`, which does not provide equivalent functionality.

### Run SystemVerilog

```bash
iverilog -g2017 -s top -o sim.vvp my_testbench.sv
vvp sim.vvp
```

Use `-s` for the top module and `-I <dir>` for include paths. Select the
language edition with `-g2012`, `-g2017`, `-g2023`, or `-glatest`;
selecting an edition does **not** mean it is fully implemented.
Specify blocks and timing checks require `-gspecify`.

`-gcommercial-unsafe` opts into nonstandard `bit`/`logic` element conversion
for whole assignments between queues and dynamic arrays, and for native
task/function value copies, when element width and signedness match.
Same-kind whole assignments remain strict. This option is not IEEE
conformance and does not claim to reproduce VCS behavior.
It also permits a narrow mixed-driver exception for an interface member only
when every conflicting task-body write is proven unreachable for that concrete
instance. Called or uncertain tasks, active writable port/ref aliases, and
non-task writers remain errors. The flag accepts a string-first `$fatal` as a compatibility
form; strict mode still requires an explicit finish number when arguments are
present.

### Run UVM

Add `-uvm` to compile with the bundled library and load its DPI backend,
including register backdoor access. No manual UVM paths or library flags are
needed.

```bash
iverilog -g2017 -uvm -s top -o sim.vvp my_testbench.sv
vvp sim.vvp +UVM_TESTNAME=my_test
```

`+UVM_TESTNAME` selects the test when the testbench calls `run_test()` without
an argument. For a bundled smoke test, run from the repository root:

```bash
iverilog -g2012 -uvm -o smoke.vvp tests/no_rand_test.sv
vvp smoke.vvp
```

For other releases, register them with
[`scripts/uvm_release_matrix.py`](scripts/uvm_release_matrix.py), then select
`--uvm=<release>`; use `--uvm-home=/path/to/uvm` for an external source tree.
Registration alone does not establish compatibility. See the
[release matrix](docs/conformance/uvm_release_matrix.md) for setup, tested
versions, and legacy recording limitations, and the
[UVM frontend guide](docs/uvm_frontend.md) for overrides such as `--uvm-no-dpi`.

## Known limitations

- **Standards support is incomplete.** Classes, constraints, containers,
  interfaces, DPI, and VPI still have unsupported forms and interactions.
  Clocking blocks, mailboxes, SVA, coverage, and `bind` have significant gaps.
  The [2017 clause matrix](docs/conformance/matrices/ieee1800_2017_clause_matrix.md)
  and [2023 survey](docs/conformance/ieee1800_2023_delta.md) define the tested
  scope; a passing example is not full conformance.
- **Application support varies.** UVM regression and individual OpenTitan
  workload passes do not establish full IEEE 1800.2 or OpenTitan/Caliptra DV
  support. Compilation alone does not prove meaningful traffic or checking.
  The [release overlays](docs/conformance/release_overlays/README.md) record
  pinned application sources, known-needed patches, and target run options.
  [Current results](docs/conformance/CURRENT_WORK.md) record revisions,
  commands, failures, and pending qualification; `DEBT` is not a pass.
- **Some legal constructs remain unsupported**, including `wait_order`,
  recursive/value-returning `randsequence` productions, imported DPI shortreal
  arrays, and fixed-size unpacked DPI export formals. Consult the clause
  matrix for detailed boundaries before relying on a feature.
- **Compatibility extensions are not IEEE conformance.** Narrow OpenTitan
  queue/dynamic-array assignment and runtime interface-array selection
  extensions have separately documented limits.
- **No hardware formal proof engine.** SVA executes during simulation; Z3
  serves constrained randomization. A proof backend is future work, and
  UPF/IEEE 1801 support is deferred.

Unsupported behavior must produce a diagnostic rather than silently change
semantics. A warning does not make a result correct. Please report suspected
silent wrong answers as bugs.

## Testing

From the repository root, using the compiler just built:

```bash
export PATH="$PWD/install/bin:$PATH"
make check                              # compiler self-test
bash .github/uvm_test.sh                 # UVM regression
bash tests/negative/run_negative.sh      # expected-error tests
make -C tgt-fpga install                 # target needed by two ivtest cases
sh .github/test.sh                       # integrated ivtest + VPI regression
bash tests/sva_nfa/run.sh                 # compare the two SVA engines
```

Harness prerequisites and failure handling are documented in the
[test-suite audit](docs/conformance/test_suite_audit_2026-07-17.md).
Compare results with the revision-specific baselines in
[CURRENT_WORK](docs/conformance/CURRENT_WORK.md).

## Contributing

[Report fork bugs here](https://github.com/dsellerbrock/iverilog-uvm/issues)
with a minimal `.sv` reproducer, exact command, compiler version, and expected
versus actual output. Use upstream's tracker only if the bug also reproduces
on official Icarus Verilog.

For changes, cite the relevant IEEE clause, fix the shared simulator behavior,
add positive/negative regressions, run affected suites, and update the status
docs. Do not patch UVM or add silent fallbacks to make tests pass. AI-assisted
contributions meet the same review and evidence requirements. See the
[contribution policy](docs/conformance/iverilog_ieee1800_uvm_manifesto.md)
and [PR template](.github/pull_request_template.md).

## Documentation

The [documentation index](docs/README.md) maps usage guides, current status,
conformance records, and historical evidence to their owning documents.

## Credits and license

Icarus Verilog is Stephen Williams' project, Copyright © 2000–2026,
[GPL-2.0+](COPYING). This fork is maintained by Daniel Ellerbrock; much of its
SystemVerilog/UVM code was written with Anthropic's Claude under human
direction and review. Upstream acceptance of this work is not implied.
Accellera UVM Core is Copyright Accellera Systems Initiative, Apache-2.0.
