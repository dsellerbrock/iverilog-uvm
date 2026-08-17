# Caliptra interface-member sensitivity

Caliptra RTL and OpenTitan RTL remained unmodified, read-only compatibility
workloads throughout this work. The compiler, runtime, regressions, and this
evidence record are the only changed material.

## Defect and fix

An interface or modport formal is represented at run time by a virtual-
interface object. Implicit sensitivity analysis found the object-handle nexus
for a selected member expression such as `req_if.addr[31:0]`, but the handle
does not change when the underlying interface signal changes. Icarus warned
that it was using conservative whole-expression sensitivity, then failed to
wake the process at all. The warning therefore described a behavioral bug,
not merely diagnostic imprecision.

Implicit `@*`, `always_comb`, and `always_latch` elaboration now retains the
existing complete `nex_input()` traversal and collects interface-member reads
during that same walk. One compiler-generated watcher per distinct dynamic
member path waits on the actual virtual-interface member and triggers the
user process's event. Ordinary net dependencies stay in the same event-or,
so mixed and multi-member expressions retain every dependency. Constant
unpacked-array words carry their canonical word number into VVP; a run-time
word selector conservatively observes every word while separately retaining
the selector expression's normal sensitivity.

VVP caches member/word edge functors for the lifetime of the interface object.
Fixed-word probes are seeded with the current element value. The dynamic-word
any-change probe toggles a private token on every array-word mutation, which
also distinguishes equal values written successively to different words.
The same indexed metadata supports explicit constant-element posedge and
negedge waits. Allocation is bounded by the number of distinct elaborated
member/word/event-kind paths; re-arming a process does not allocate another
probe.

The permanent reducer covers packed selects, fixed unpacked members, a
descending nonzero unpacked range, a run-time member index, mixed ordinary-net
and interface dependencies, multiple interface dependencies, `always_comb`,
plain `always @*`, `always_latch`, and an explicit constant-element posedge.
The final pre-fix reducer emits eight warnings and then reaches the old
array-member edge-functor assertion while arming the explicit selected wait.
An earlier implicit-only form ran far enough to prove that member changes did
not retrigger. The corrected compiler emits no warning, runs `PASSED`, and
Slang 11.0.415 accepts the same source with zero errors and zero warnings.
The assertion is a robustness failure on unsupported internal metadata, not
evidence of attacker control or memory corruption. The new indexed VVP
instructions validate their object stack and member/word identity so malformed
raw bytecode now reports a bounded diagnostic instead of asserting.

The unchanged Caliptra top-level VVP compile had 22 instances of the defect:
four in `axi_dma_ctrl`, one each in `axi_mgr_rd` and `axi_mgr_wr`, and eight
each in `el2_ifu_iccm_mem` and `el2_lsu_dccm_mem`. This branch removes all 22.
It exits 0 in 15.14 seconds with peak RSS 865,341,440 bytes under the 1 GiB
guard. Because this branch is independent of the integral-member synthesis
warning change, it still reports that branch's 180 unrelated warnings. A
temporary integration of both changes is the authoritative zero-warning
check. That integration replayed the warning fix as `8cddc58bb` and this
sensitivity fix as `3a4449cac` on current `main`, rebuilt and installed
Icarus from scratch, then compiled the unchanged Caliptra file list with the
invocation recorded below. It exited 0 with zero
stdout, zero errors, zero `sorry` diagnostics, and zero warnings of any kind.
The resource-capped compile took 15.25 seconds and reached 872,509,440 bytes
maximum RSS; its emitted VVP image was 67,920,268 bytes. The evidence directory
was `/tmp/caliptra-warning-integration.UIpcA8`.

## Tool versions and invocation gotchas

All compiler and simulator process trees used the pinned resource wrapper
with 45 seconds CPU per process and a 1 GiB aggregate RSS ceiling:

```sh
RUNNER=/Users/danielellerbrock/projects/iverilog_uvm/evidence/sv-tests-c4229f3/full-all-final-parity-replay-20260815T1845MDT/tool-bin/resource-runner
```

Its SHA-256 is
`0198ed8af4ae1c52611a67365c78b5e81c67a2b3e4f3608799238b3e2edf7bdf`.
Ambient `iverilog` and `vvp` were never used.

- Homebrew GNU Bison 3.8.2 is required. macOS `/usr/bin/bison` is Apple
  Bison 2.3 and cannot regenerate this parser. Put
  `/usr/local/opt/bison/bin` first in `PATH` for configure and build.
- This host's ambient `python3` is Apple Python 3.9.6. It is not the
  OpenTitan interpreter. The verified OpenTitan environment uses Python
  3.13.14 with FuseSoC 2.4.5, HJSON 3.1.0, and Mako 1.3.10. The separate
  sv-tests Python 3.13.14 environment carries FuseSoC 2.4.3; mixing its
  imported package with the 2.4.5 executable is invalid.
- Invoke a virtual-environment Python through its logical environment path.
  Do not apply `realpath` or `Path.resolve()` first: resolving to the Homebrew
  base interpreter bypasses `pyvenv.cfg` and changes `sys.path`. A FuseSoC
  console script can also be a shell trampoline rather than a direct Python
  shebang, so pass the matching interpreter explicitly instead of guessing
  from arbitrary shebang text.
- The real OpenTitan register-generation proof used that Python to invoke
  `util/regtool.py -r -t <evidence-dir> hw/ip/uart/data/uart.hjson`; its
  generated `uart_reg_pkg.sv` and `uart_reg_top.sv` were byte-identical to
  the checked-in files. The integrated `--setup-only` FuseSoC flow also ran
  `ralgen`, `csr_assert_gen`, and `regtool.py -s`. This is the required
  generator chain; compiling hand-copied generated RTL is not an equivalent
  OpenTitan baseline.
- Configure enabled libffi on this machine. `pkg-config --cflags libffi`
  returns an SDK include path that did not supply the build's `ffi.h` in the
  required form. The working flags are
  `CPPFLAGS=-I/usr/local/opt/libffi/include` and
  `LDFLAGS=-L/usr/local/opt/libffi/lib`.
- Configure and build use `CFLAGS=-g0 -O2 CXXFLAGS=-g0 -O2`. Full debug
  information for the large `vvp/vthread.cc` translation unit can exceed the
  45-second CPU cap even when the optimized build is healthy.
- Immediately after configure, an isolated object request can finish the
  compilation and then fail while moving its dependency file if generated
  `dep/` has not been initialized. Run the normal bootstrap build first or
  create that generated directory before a direct object build.
- A tool command that yields a session identifier is still running. Poll the
  same session until it reports an exit code; starting a replacement creates
  duplicate builds and misleading resource symptoms.
- Caliptra's `+timescale+1ns/1ps` belongs in an Icarus command file, not as a
  free driver argument. Nested `-f` paths resolve relative to the command file
  containing them, so the wrapper file uses an absolute path to
  `src/integration/config/caliptra_top.vf`.
- The unchanged Caliptra file list requires all three environment variables:
  `CALIPTRA_ROOT`,
  `CALIPTRA_PRIM_ROOT=<root>/src/caliptra_prim_generic`, and
  `CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic`. Omitting the latter
  settings expands primitive paths such as `/rtl/_flop_en.sv`.
- The verified differential compiler is
  `/Users/danielellerbrock/oss-cad-suite/bin/slang`, version
  11.0.415+8acc660a2, invoked with `--std 1800-2017`.

The exact Caliptra wrapper file is:

```text
+timescale+1ns/1ps
+define+CALIPTRA_INTERNAL_TRNG
+define+CALIPTRA_AXI_DMA_ADDR_WIDTH=32
-f /Users/danielellerbrock/projects/iverilog_uvm/caliptra-rtl/src/integration/config/caliptra_top.vf
```

The compile invocation is:

```sh
env CALIPTRA_ROOT=/Users/danielellerbrock/projects/iverilog_uvm/caliptra-rtl \
    CALIPTRA_PRIM_ROOT=/Users/danielellerbrock/projects/iverilog_uvm/caliptra-rtl/src/caliptra_prim_generic \
    CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic \
    "$RUNNER" ./local-install/bin/iverilog -g2012 -s caliptra_top \
    -o <evidence-dir>/caliptra_top.vvp \
    -f /tmp/caliptra_top_iverilog_20260816.f
```

The command-file `+define+...` spelling is intentional. Shell-style `-D`
arguments are also valid when passed directly, but mixing the two conventions
while moving options between shell and command-file contexts is a common
source of false missing-primitive or missing-macro failures.

## Remaining boundary

Run-time indexed implicit member reads use whole-array any-change sensitivity,
which is conservative and conformant for wakeup completeness. Exact
expression-result edge semantics for a run-time-selected element, virtual-
interface handle rebinding while a wait is armed, and additional non-signal
member kinds remain separate work; unsupported paths must remain loud rather
than silently selecting an arbitrary object or word.
