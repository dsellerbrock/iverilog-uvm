# OpenTitan and Caliptra tool invocation ledger

This ledger records tool provenance and invocation traps discovered while
running the unmodified external compatibility workloads. OpenTitan remained
clean at `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`; Caliptra RTL remained clean at
`bd31614182fb56e55578f48086a10ded650434fd`. Generated output and logs were
written under `evidence/`, never into either source checkout.

## Bounded execution

Every compiler or simulator process tree used the local `resource-runner`
with a 45-second CPU limit per process and a 1 GiB aggregate RSS ceiling:

```sh
RUNNER=evidence/sv-tests-c4229f3/full-all-final-parity-replay-20260815T1845MDT/tool-bin/resource-runner
"$RUNNER" PROGRAM ARG...
```

This cap turns recursive preprocessing, compiler runaway, and simulator hangs
into explicit failures. It is not a substitute for the matrix's own per-job
timeouts, which also terminate complete process sessions.

## Python, FuseSoC, and register generation

The known-good OpenTitan environment is:

| Component | Version |
|---|---|
| Python | 3.13.14 |
| FuseSoC executable and imported package | 2.4.5 |
| HJSON used by `regtool` | 3.1.0 |
| Mako used by `regtool` | 1.3.10 |

The interpreter and FuseSoC executable came from the same environment. The
matrix invocation must make that relationship explicit:

```sh
OT_PY=evidence/opentitan-7a3ad34-final-parity-baseline-20260815T1925MDT/tool-env/bin/python
OT_FUSESOC=evidence/opentitan-7a3ad34-final-parity-baseline-20260815T1925MDT/tool-env/bin/fusesoc
"$RUNNER" "$OT_PY" scripts/opentitan_matrix.py \
  --opentitan-root /path/to/opentitan \
  --build-root /path/to/evidence/matrix \
  --iverilog /path/to/current/install/bin/iverilog \
  --fusesoc "$OT_FUSESOC" --fusesoc-python "$OT_PY" \
  --lane all
```

Important traps:

- `/usr/local/bin/python3` is Python 3.14.5 but does not see FuseSoC on its
  normal import path.
- `/usr/bin/python3` is Python 3.9.6 and drives the user-installed FuseSoC
  2.4.5, but current OpenTitan Python sources use syntax requiring Python
  3.10 or newer.
- The separate sv-tests Python 3.13.14 environment imports FuseSoC 2.4.3.
  Pairing it with the 2.4.5 executable is now rejected before discovery.
- Do not call `Path.resolve()` or `realpath` on a virtual-environment Python
  before execution. Using the base Homebrew binary bypasses `pyvenv.cfg`,
  changes `sys.path`, and makes installed packages disappear.
- A FuseSoC console script may use either a direct Python shebang or a shell
  trampoline. The matrix only parses a bounded conventional Python shebang as
  data, accepts only inert interpreter flags, and rejects environment
  assignments plus executable `-c`/`-m` options. It never executes shebang text
  through a shell. Use `--fusesoc-python` for wrappers and ambiguous
  installations.

The register-generation proof used the real UART HJSON and wrote to evidence:

```sh
"$RUNNER" "$OT_PY" /path/to/opentitan/util/regtool.py -r \
  -t evidence/opentitan-tool-invocation-20260816/regtool-uart-rtl \
  /path/to/opentitan/hw/ip/uart/data/uart.hjson
```

The resulting files were byte-identical to OpenTitan's checked-in RTL:

| File | SHA-256 |
|---|---|
| `uart_reg_pkg.sv` | `106f8da3d41f8cfe585a58e91c251e23e76c81d25956cb751f61644023dfa01b` |
| `uart_reg_top.sv` | `8c40c957fbd7c1155f58d2c7696340b7ea6b82c2b0626ec684463f991538ae27` |

A bounded `--setup-only` matrix job for
`lowrisc:darjeeling_dv:ac_range_check_sim:0.1` also exercised the integrated
generator chain. FuseSoC prepared `ralgen` and `csr_assert_gen`, generated the
CSR assertion core, then called `util/regtool.py -s` to produce the UVM RAL
package in the build-local generator cache. The setup finished `SETUP_ONLY`
with OpenTitan still clean. Current inventory at this revision is 264 RTL, 128
SVA, 61 UVM-compile, and 77 runtime jobs; the 91 literal simulation targets are
61 UVM, 16 directed, eight Verilator-only, and six elaboration-only targets.

## Icarus build and harness invocation

- macOS `/usr/bin/bison` is 2.3 and fails on the repository's typed Bison
  destructors. Prefix configure and make commands with
  `PATH="/usr/local/opt/bison/bin:$PATH"`; the verified parser generator is
  Bison 3.8.2.
- Under the 45-second CPU wrapper, compiling the very large `vvp/vthread.cc`
  with full debug information can be killed during an otherwise valid build
  and leave a misleading `.o.tmp` rename message. Rebuilding that one object
  with `-g0 -O2` under the same memory/CPU guard distinguishes compiler cost
  from a filesystem failure.
- The legacy and JSON ivtest focus harnesses share `ivtest/log`. Run them
  serially or give each an isolated work directory; concurrent runs can delete
  one another's log and create a false failure.
- Always invoke the compiler and VVP runtime installed from the worktree under
  test. Ambient `/usr/local/bin/iverilog`, `vvp`, and generated-script
  shebangs can select stale binaries.

## Caliptra invocation

The standalone Caliptra top uses the unmodified file list
`caliptra-rtl/src/integration/config/caliptra_top.vf` with these required
arguments:

```text
-g2012
+timescale+1ns/1ps
-s caliptra_top
-DCALIPTRA_AXI_DMA_ADDR_WIDTH=32
-DCALIPTRA_INTERNAL_TRNG
-DRV_TOP=caliptra_top.rvtop
-gassertions
```

The `+timescale+1ns/1ps` line belongs in an Icarus command file; omitting it
uses Icarus's default 1s/1s and changes the workload. These defines select the
same integration topology as the checked-in Caliptra configuration; they are
compiler options, not source patches.

At this checkpoint the full Caliptra `-tnull` parse/elaboration workload fits
under the 1 GiB cap when the null target skips target-graph construction. The
full VVP image still exceeds that aggregate cap, while the DUT-only VVP image
compiles below it. A standalone DUT image also reaches Caliptra's intentional
end-of-test fatal logic, so focused value/diagnostic regressions remain the
authority for compiler runtime status rather than that final process exit code.
