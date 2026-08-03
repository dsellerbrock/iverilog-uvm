# OpenTitan synthesis, SVA, UVM and runtime matrix

`scripts/opentitan_matrix.py` is the canonical census driver for the current
OpenTitan closure campaign.  It replaces one-off source lists with a pinned,
machine-readable result for every selected FuseSoC core.

## Pass criteria

The runner keeps these outcomes distinct:

| Status | Meaning |
|---|---|
| `PASS` | Setup, compile, and (for the runtime lane) execution completed with no hard diagnostic or semantic-degradation warning. |
| `DEBT` | The process exited successfully, but the compiler reported a warning, ignored construct, approximation, fallback, unresolved operation, or other possible semantic loss. This is **not** a conformance pass. |
| `FAIL` | Compilation returned nonzero or emitted a hard error even if its exit status was zero. |
| `DEPENDENCY_ONLY` | The CAPI core is a package/fileset provider with no standalone top. Its sources are covered through runnable parent top-level jobs. |
| `SETUP_*`, `*_TIMEOUT`, `RUNTIME_FAIL`, `MATRIX_ERROR` | The named build, execution, or census infrastructure stage did not complete. |

An exit status of zero is therefore necessary but insufficient.  In
particular, compile-progress stubs, ignored constraints, dropped loop bodies,
unresolved class/interface calls, covergroup fallbacks, altered scheduling, and
unsupported SVA lowering remain visible debt.

FuseSoC's unsigned-core trust-file notice and its legacy-backend migration
notice are explicitly allowlisted because neither changes the selected HDL or
its meaning.  Every other setup warning is retained.  Ambiguous virtual-core
provider selection is a build-integrity/reproducibility finding; it is not by
itself classified as a cybersecurity vulnerability.

## Reproducible inputs

Each job pins both of the provider families that otherwise depend on FuseSoC's
selection order:

- `lowrisc:prim_generic:all:0.1`
- `lowrisc:systems:top_earlgrey:0.1`, or
  `lowrisc:systems:top_darjeeling:0.1` for Darjeeling cores

The `top_englishbreakfast` core intentionally has no virtual-core `mapping`
stanza. For English Breakfast jobs, the runner generates a build-local CAPI
mapping core that pins its RACL, AST, flash-register, flash-package, and random
constant providers, then selects that mapping alongside the generic primitive
mapping. This avoids both the Earl Grey provider conflict and FuseSoC's
nondeterministic-provider fallback without modifying the OpenTitan checkout.

The JSON report also records the OpenTitan commit and dirty state, compiler and
FuseSoC versions, exact setup and compile commands, selected top, diagnostics,
durations, log paths, and a hash of compiler output. The compiler fingerprint
includes the driver, the actual `ivl` compiler engine, the VVP target and
runtime, normal and synthesis configurations, installed UVM DPI module, and
installed UVM source tree when present. Hashing only the `iverilog` driver is
insufficient because that binary can remain unchanged when the compiler engine
is rebuilt. A dirty OpenTitan tree is reported rather than modified.

At OpenTitan revision `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`, initial
discovery finds 267 RTL/default-target candidates, 109 standalone SVA/formal
jobs, and 80 UVM simulation jobs. Some RTL candidates are CAPI package/fileset
providers without a toplevel; the runner records those as `DEPENDENCY_ONLY`
rather than falsely reporting a compiler or setup failure. The runtime lane
reuses the same 80 simulation cores but only earns `PASS` after executing the
generated image. The SVA count combines 54 assertion/bind cores with 55 FPV
cores. Three top-specific `rv_plic_fpv` cores live in an `*_ip` VLNV library;
their formal sources and target belong only to the SVA/formal lane, so they are
excluded from RTL rather than being compiled twice under different labels.

## Commands

The runner requires explicit roots so a report cannot silently use a different
checkout or compiler from the one under test.  A small ADC-control census is:

```sh
python3 scripts/opentitan_matrix.py \
  --opentitan-root /path/to/opentitan \
  --build-root /path/to/build/matrix/adc_ctrl \
  --iverilog /path/to/install/bin/iverilog \
  --fusesoc /path/to/opentitan/.venv-iverilog/bin/fusesoc \
  --lane rtl --lane sva --lane uvm \
  --ip adc_ctrl
```

List the full discovered inventory without building it:

```sh
python3 scripts/opentitan_matrix.py \
  --opentitan-root /path/to/opentitan \
  --build-root /path/to/build/matrix \
  --iverilog /path/to/install/bin/iverilog \
  --fusesoc /path/to/opentitan/.venv-iverilog/bin/fusesoc \
  --lane rtl --lane sva --lane uvm --list
```

Run all four lanes with four independent cores in flight:

```sh
python3 scripts/opentitan_matrix.py \
  --opentitan-root /path/to/opentitan \
  --build-root /path/to/build/matrix/full \
  --iverilog /path/to/install/bin/iverilog \
  --fusesoc /path/to/opentitan/.venv-iverilog/bin/fusesoc \
  --lane all --jobs 4
```

`--core` selects an exact VLNV; `--ip` is a repeatable case-insensitive name or
description filter.  Runtime plusargs can be repeated with `--runtime-arg`.
Timeouts are independently configurable for setup, compile, and runtime. The
defaults are 600 seconds for setup, 600 seconds for compile, and 300 seconds for
runtime. Each command starts in its own process session; a timeout terminates
the whole session, including compiler/preprocessor descendants, before the next
job starts. Interrupting a census cancels queued jobs, terminates all active
command sessions, and preserves the last atomic JSON/Markdown checkpoint.
This makes bounded termination part of the evidence instead of allowing a hung
lowering pass or an orphan compiler to consume the remainder of the campaign.

The default reports are `opentitan-matrix.json` and `opentitan-matrix.md` under
the build root.  `DEBT` and all failure/timeout statuses make the runner return
nonzero, allowing the matrix to become a genuine zero-debt gate.

## First whole-RTL checkpoint

A pinned pre-G20 run at OpenTitan `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`
completed 113 of 267 RTL jobs before deliberate interruption: 4
`COMPILE_TIMEOUT`, 16 `DEBT`, 59 `DEPENDENCY_ONLY`, 30 `FAIL`, and 4
`SETUP_FAIL`. All four timeouts were independent Ibex cores and each spent the
then-configured 1800 seconds in synthesis lowering. A process sample located the
hot path under `NetProcTop::synth_async`, dominated by repeated nexus connects.
This is a partial root-cause census, not a pass-rate claim.

That checkpoint exposed two infrastructure defects now fixed in the runner:
the 1800-second default made iteration needlessly slow, and a timed-out driver
could leave its compiler descendants running. The default is now 600 seconds
and timeout/interrupt cleanup covers the complete command session. The next
whole-RTL run must start from a new build root and compiler fingerprint; results
from the partial checkpoint must not be merged with the post-G20 compiler.

The first exact post-G20 Ibex-core rerun removed the immediate synthesis
segfault exposed by a statically non-overlapping packed write, then reached the
new 600-second limit. It was recorded as `COMPILE_TIMEOUT` after 600.085 seconds
and left no driver, preprocessor or compiler descendant. The bounded cleanup is
therefore verified; the hot synthesis path remains an open G22 compiler gap.

The later `ibex-disjoint-precise-v2` replay reaches the same independent hot
path and times out after 600.078 seconds with no orphan. It no longer reports
the `ibex_alu.sv` partial-field latch error: the lower field is fully assigned
on both `if/else` paths and now composes with its independently driven upper
bit. The sole remaining warning in that exact log is the legal constant-only
`always_comb` in `ibex_cs_registers.sv`; G26 removes that false debt after the
replay. The timeout itself remains open and is not a cybersecurity finding.

The subsequent disjoint-packed-process and precise-select-sensitivity fixes
move the exact Darjeeling RACL target to a clean result at the same pinned
OpenTitan revision: `PASS`, exit 0, no hard errors, no semantic-debt lines, no
timeout, and 0.304 seconds. This is one exact core witness, not a whole-suite
claim; its compiler fingerprint must remain separate from earlier `FAIL` and
`DEBT` reports.

The final ownership-union and retained-behavioral-driver validation was replayed
in `racl-disjoint-precise-v4`: the result remains `PASS` with the same zero-error,
zero-debt disposition and a 0.357-second compile.

After the complete-branch refinement and G26 warning cleanup,
`racl-disjoint-precise-v6` is the final witness: `PASS`, exit 0, zero hard
errors, zero semantic-debt lines, no timeout, `security_vulnerability=false`,
and a 0.334-second compile. This replay includes the adversarial per-bit-state
guard added after v5.

## First ADC-control matrix witness

The first three-lane run exposed the intended distinction immediately:

| Lane | Result | Current frontier |
|---|---|---|
| RTL synthesis | `DEBT` | Compile succeeds; one conservative `always_*` sensitivity warning remains recorded. |
| Standalone SVA/formal | `FAIL` | After supplying UVM to the unmodified formal dependency graph, `adc_ctrl_fsm_sva_if.sv` refers to the simulation hierarchy `tb.dut` while the formal target's top is `adc_ctrl`. This is presently an OpenTitan target/topology mismatch, followed by compiler semantic-debt warnings; it is not evidence of a cybersecurity vulnerability. |
| UVM compile | `DEBT` | Compile and code generation succeed with no hard errors, but 153 unique warning/degradation lines remain. |

The UVM warning count is a triage count, not a defect count: one root language
or lowering bug can fire at many call sites, and one line can contain several
semantic consequences.  Work proceeds by the first causal diagnostic and by
clusters (typing/context, calls, constraints, interfaces, coverage, containers,
scheduling, SVA), with value- and behavior-checking regressions added for every
compiler fix.
