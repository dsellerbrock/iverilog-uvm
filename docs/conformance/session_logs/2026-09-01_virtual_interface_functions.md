# Virtual-interface functions and inherited class parameters

## Scope and standards basis

This increment is based exactly on `origin/main` `99bf9c549` and is developed
on `agent/opentitan-vif-function-after248-arm64-20260901`. The implementation
targets the shared IEEE 1800-2017/2023 rules in 8.13, 9.2.2.2.1, 13.4,
13.5, and 25.9. OpenTitan, Caliptra, and Accellera UVM sources remain
unmodified.

The supported call shape is a value-returning function selected through an
unparameterized virtual-interface handle with input-only formals. The receiver
may be rebound to any compatible concrete instance. Output, inout, and ref
function arguments, fixed-unpacked function arguments or returns, complete
parameterized-interface/modport specialization, and synthesis lowering remain
outside this increment.

## Implementation

Frontend resolution no longer commits to the first elaborated interface
instance. A dynamic VIF function expression retains every compatible concrete
method scope and one scope-keyed argument row per candidate. Each explicit
actual is elaborated in the candidate formal's assignment context. Each
omitted actual duplicates the candidate's declaration-scoped default, so the
default may read an interface member or an earlier formal.

Target lowering evaluates the receiver once, branches by its bound interface
scope, evaluates only the selected row, and invokes that method. Typed call
opcodes preserve packed scalar/wide, real, string, class-handle, queue, and
dynamic-array results. A discarded result still calls the method and pops the
matching stack; a null handle uses a dedicated fatal path. The VVP object
stack uses growable storage rather than the former fixed 32-entry arrays.

Automatic functions use their ordinary private call frame. A static function
needs a different rule: its formals are shared, but nested evaluation of the
outer call's actuals must not corrupt the incomplete outer row. VVP therefore
stages a typed invocation-local overlay during argument setup, commits it
immediately before the body, and leaves recursion entered from the body on the
ordinary shared-static storage required by 13.4.2.

Dependency discovery walks the selected interface function body for
`always_comb`. A rootless declaration scope supplies the function signature
without emitting its declaration-only delay, supply, or resolver objects into
the target graph. This preserves the existing delayed-interface regression
while adding a constant interface-port-array function-body dependency.

## UART follow-on found by the full application replay

The first stable 530-row OpenTitan replay exposed a direct branch regression
in `uart_base_vseq.sv:140`. The legal expression
`CyclesWithNoAccessesThreshold * 2` names a value parameter declared in the
specialized `cip_base_vseq` superclass and passes it to
`task automatic wait_clks(int num_clks)` through a virtual interface.

`symbol_search()` checked parameters only in the current class scope; its
superclass walk covered enum literals but not value parameters. Frontend
compile-progress recovery therefore produced one null actual per concrete VIF
candidate. Main's old statement emitter skipped each null store. The new
unified emitter grouped a null actual with non-input formal direction and
reported two false target errors even though both exported formals were
correctly `input`.

Two fixes are deliberately separate:

1. After local parameter lookup, a class scope now searches specialized
   superclasses nearest-first and returns the inherited value. UART therefore
   passes 160, not an unstored/X value.
2. VIF task statement rows have a sparse compatibility marshaller that
   preserves main's existing compile-progress behavior for an actual that has
   already failed elaboration. Value-returning VIF expressions and ordinary
   subroutine calls remain strict, and a strict missing actual has its own
   diagnostic instead of the misleading direction message.

The paired `sv_inherited_class_parameter_vif_task` reducer uses two interface
instances, an implicit-input task formal, a parameterized base class, and an
inherited body parameter. Exact main `99bf9c549` warns twice, runs, and observes
0 instead of 160. The branch passes in both editions. An authentic UART compile
now contains neither the inherited-parameter warnings nor the two VVP target
errors.

## Validation

- Focused virtual-interface function/inherited-parameter legacy: **31/31**.
- Focused JSON/VVP: **31/31**. Each list contains 15 paired 2017/2023
  language cases plus one `-g2012` `always_comb` control.
- Exact-main reducer: red at runtime, with two inherited-parameter warnings.
- Slang 11.0.448 accepts the reducer with zero errors or warnings under both
  `--std 1800-2017` and `--std 1800-2023`.
- Authentic OpenTitan UART compile: return 0, zero
  `CyclesWithNoAccessesThreshold` warnings, and zero VVP target errors.
- Full broad compiler validation: JSON/VVP **1,320 ran / 0 failed** (17 NI,
  45 expected-fail), legacy SV **2,242/2,242**, negatives **149/149**,
  real-DPI UVM **354/354** with zero skips, and VPI **103/103**. The shared
  `ivtest/vsim` users ran sequentially.
- The final 530-row OpenTitan aggregate is 192 `PASS`, 20 `DEBT`, 104 `FAIL`,
  16 `RUNTIME_FAIL`, 157 `DEPENDENCY_ONLY`, 35 `UPSTREAM_INVALID`, and 6
  `SETUP_FAIL`. RTL is 93 pass / 153 dependency / 18 upstream-invalid. SVA is
  99 pass / 6 debt / 2 fail / 4 dependency / 17 upstream-invalid. UVM compile
  is 12 debt / 46 fail / 3 setup-fail; runtime is 2 debt / 56 fail / 16
  runtime-fail / 3 setup-fail. UART alone advances: compile `FAIL` to `DEBT`
  and runtime `FAIL` to `RUNTIME_FAIL`. The latter reports a separate null-VIF
  call near 497,725,923 ps and continues to the 504,840,923 ps UVM marker. No
  clean OpenTitan UVM pass is claimed.
- The frozen Caliptra/Adams Bridge census completed 105 manifest jobs and 420
  compiler invocations in 86.361 seconds without a timeout: 52 `PASS`, 1
  `DEBT`, 51 `SHARED_SOURCE_OR_CONFIG`, and 1 `SOURCE_ORDER_DEBT`. Icarus is
  53/105 in each assertions, no-assertions, and synthesis lane versus Slang
  54/105. Every recorded field is unchanged from the prior final and available
  clean post-#241 mainline census. This is an RTL/SVA/synthesis manifest census,
  not complete Caliptra DV/UVM.

## Tool and invocation notes

- Build through
  `evidence/arm64-tooling/resource-runner` with `make -j1`, Homebrew Bison
  `/opt/homebrew/opt/bison/bin/bison`, and `/usr/bin/flex`. Apple's Bison 2.3
  cannot generate this grammar. The runner keeps its 45-second per-process CPU
  guard and imposes no memory or output-size ceiling.
- Normal runs use only the worktree's `local-install/bin/iverilog` and `vvp`.
  A full application matrix instead uses a frozen snapshot of that complete
  install; running `make install` while a matrix is active otherwise mixes
  compiler components.
- OpenTitan uses the native ARM Python 3.13 virtual environment and FuseSoC
  2.4.5/Edalize 0.6.3. Resolve neither the venv Python symlink nor generated
  response-file paths; doing so bypasses `pyvenv.cfg` or changes relative
  source lookup. Run the response file from its generated FuseSoC work
  directory. Register RTL is generated with OpenTitan's `util/regtool.py`.
- Caliptra is frozen at `bd31614182fb56e55578f48086a10ded650434fd`
  with Adams Bridge `e59eba955eac2a1adcb059f250641ede78e304be`, native ARM
  Python 3.13, and Slang 11.0.448. The complete DV/UVM flow remains outside the
  static census where its external UVMF/proprietary inputs are unavailable.
  The post-fix snapshot fingerprints are driver `713f4086`, compiler engine
  `a9799e9b`, `vvp.tgt` `000dd51c`, and runtime `60cbeaae` (SHA-256 prefixes).
- The legacy and VPI harnesses have distinct logs but share `ivtest/vsim`.
  Never run them concurrently. The JSON/VVP and legacy sweeps are also kept
  sequential for deterministic artifacts.
- `tgt-fpga` is not built by the top-level `make`; a complete JSON/VVP sweep
  may require `make -C tgt-fpga` and `make -C tgt-fpga install` first.
- A compiler driver return of zero is insufficient for application
  classification. Inspect target diagnostics, UVM summaries, and runtime
  assertions. Quiet UVM output is not evidence of a hang; use the established
  simulation-time tracing and interruptible VVP mode when diagnosing progress.
- Keep the matrix driver itself under the resource runner. The preserved raw
  concurrent OpenTitan runtime campaign omitted that wrapper and, while the
  canonical UVM sweep loaded the host, ADC and TL-agent reached the matrix's
  300-second wall timeout. Exact single-row native-ARM64 replays through the
  45-second CPU guard restored both prior `RUNTIME_FAIL` classifications in
  61.35 and 56.43 seconds wall time. The final aggregate substitutes only those
  two guarded results; it does not erase the raw timeout evidence or promote
  either row to a pass.
