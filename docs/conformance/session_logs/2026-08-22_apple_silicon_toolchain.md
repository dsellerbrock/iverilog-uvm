# Apple Silicon toolchain migration

This record captures the host/tool transition used for the continuing
OpenTitan and Caliptra compatibility campaign. It does not replace the frozen
August 15 baselines: all compiler, runtime, resource, and pass/fail verdicts
from those x86_64/Rosetta environments are historical until rerun natively.

## Native host and Python

- `uname -m` and `arch` report `arm64`; the process is not translated.
- `/opt/homebrew/opt/python@3.13/bin/python3.13` is Python 3.13.15, arm64.
- The campaign resource monitor uses a fresh Python 3.13 environment with an
  arm64 `psutil` 7.2.2 wheel.
- The ambient `/opt/homebrew/bin/python3` is Python 3.14.7. It is native, but
  it is not used for OpenTitan because OpenTitan requires Python `<3.14`.
- The old evidence environments point at removed `/usr/local` Python paths and
  contain x86_64 native wheels. They must be recreated, never relinked.

The native resource launcher preserves the existing 45-second CPU and 1 GiB
aggregate-RSS implementation:

```sh
RUNNER=/path/to/evidence/arm64-tooling/resource-runner
"$RUNNER" PROGRAM ARG...
```

On macOS the monitor needs permission to inspect descendant processes. A
sandbox denial exits 126 before launching the compiler and is an environment
failure, not an Icarus test failure.

## Clean Icarus rebuild

The prior install prefix was moved aside and the worktree was rebuilt from a
`make distclean` state. Native Homebrew Bison, libffi, and Z3 were selected,
and debug information was disabled to keep the largest compilation bounded:

```sh
"$RUNNER" /usr/bin/env \
  PATH=/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:/usr/bin:/bin \
  CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include" \
  LDFLAGS="-L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib" \
  CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2" \
  ./configure --prefix="$PWD/local-install" --enable-libveriuser
"$RUNNER" make -j1
"$RUNNER" make -C tgt-fpga -j1
"$RUNNER" make install
"$RUNNER" make -C tgt-fpga install
"$RUNNER" make installuvm
```

`make -j2` is not suitable under this cap on this host: two healthy Clang C++
processes exceeded 1 GiB aggregate RSS and were terminated by the monitor.
Serial `-g0 -O2` compilation completed, including `vvp/vthread.cc`. The parser
generation signature remained 535 shift/reduce and 1115 reduce/reduce
conflicts. The compiler, runtime, target bundles, VPI modules, UVM DPI module,
FPGA target, and installed archives were then verified as arm64.

`iverilog -V` still prints the configure-time `Bundled UVM ... (not installed)`
line after `make installuvm`, even though the installed UVM sources and arm64
`uvm_dpi.vpi` are present. The migration check therefore verifies the installed
paths and binary architecture directly instead of using that banner as proof.

## OpenTitan invocation

Create a new environment using the native base interpreter and OpenTitan's
locked, hashed requirements. Invoke the matrix, FuseSoC, dvsim, regtool, and
reggen through that environment's logical Python path. In particular, do not
execute `util/regtool.py` via its ambient `python3` shebang and do not resolve
the venv symlink before execution. `regtool.py` is the CLI that drives the
checked-in `util/reggen/` package; there is no standalone `util/reggen.py`:

```sh
OT_PY=/path/to/native-opentitan-tool-env/bin/python
OT_FUSESOC=/path/to/native-opentitan-tool-env/bin/fusesoc
"$RUNNER" "$OT_PY" scripts/opentitan_matrix.py \
  --opentitan-root /path/to/opentitan \
  --build-root /path/to/evidence/matrix \
  --iverilog "$PWD/local-install/bin/iverilog" \
  --fusesoc "$OT_FUSESOC" --fusesoc-python "$OT_PY" \
  --lane all
"$RUNNER" "$OT_PY" /path/to/opentitan/util/regtool.py --help
```

Generated register output and all build products stay outside the unmodified
OpenTitan checkout. The Caliptra checkout is likewise never modified.

At frozen OpenTitan revision `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`,
the ARM64 `libcst==1.8.6` wheel adds `pyyaml-ft>=8.0.0`, but that
platform-specific edge is absent from `python-requirements.txt`. A direct
`pip install --require-hashes` therefore fails closed. The native environment
was reconstructed without dependency resolution from the complete explicit
lock, then the one missing ARM wheel was downloaded and pinned separately:

```text
pyyaml-ft==8.0.0
sha256:30c5f1751625786c19de751e3130fc345ebcba6a86f6bddd6e1285342f4bbb69
```

The supplemental wheel is stored under `evidence/arm64-tooling/wheels/`, and
its hash-pinned requirement is
`evidence/arm64-tooling/opentitan-arm64-supplement.txt`. `pip check` then
reported no broken requirements. The wheel hash also exactly matches the
ARM64 CPython 3.13 `pyyaml-ft` entry in OpenTitan's checked-in `uv.lock`; no
unreviewed binary is being added to Git. The resulting pinned versions are
Python 3.13.15, FuseSoC 2.4.5, Edalize 0.6.3, dvsim 1.34.1, HJSON 3.1.0, and
Mako 1.3.10; all native modules are arm64. The full `uv.lock` is not
substitutable for this baseline because it resolves Edalize 0.6.8.

## Native validation checkpoint

The rebuilt compiler fingerprint is:

| Component | SHA-256 |
| --- | --- |
| installed `iverilog` | `674e90bd3c81f83836de491873ef8bd0dc7c8ed685fa240ac2eef6cb02c2ab14` |
| installed `vvp` | `88b92b5a0c7b1453e9ea9a1fc885ff7dd8400aef5b4ee576960b5d0fd37efcaf` |
| installed `ivl` | `c637d552ef32e7253d942f10af39de1de28321cd3d317743cf0ad183c290b380` |
| installed `vvp.tgt` | `e72ea36571bc7355dc467a8b00d6c7d1142edc6c2bef3ea419a5e8320c414adc` |
| installed `uvm_dpi.vpi` | `23a2d7a5a0696d0102f7ad254a7c142688202824caf19772c5583b74ecc85dd1` |

All of these Mach-O files, the rebuilt VPI objects, and the native Python
extension modules report arm64. A full active-worktree scan found 470/470
Mach-O files and 4/4 static archives with arm64 content and no x86-only binary.
The only stale x86 object found is quarantined outside the worktree under
`/private/tmp/iverilog-pre-arm64-artifacts-20260822/`. Focused native
regressions passed as follows:

- Caliptra SVA compatibility: 52/52 legacy and 12/12 JSON.
- Caliptra/Slang differential: 19/19.
- Interface synthesis: 3/3 legacy and 3/3 JSON.
- Interface sensitivity: 1/1 legacy and 1/1 JSON.
- Virtual-interface event/null handling: 5/5 legacy and 5/5 JSON.
- VPI regression: 97/97.
- OpenTitan matrix self-test: pass, including rejected x86_64 and wrong-version
  Darwin Python probes.

The matrix retains a portable `python3` shebang for Intel macOS and Linux, but
its Apple Silicon campaign path validates both the driver process and the
selected FuseSoC interpreter. A native Python 3.13 UART inventory passed; an
otherwise identical invocation through ambient arm64 Python 3.14.7 failed
before discovery with exit 2 and an instruction to invoke the 3.13 path.

Three real OpenTitan tool flows were also exercised without modifying its
checkout. `regtool.py -r` regenerated UART RTL outside the checkout, byte for
byte matching the checked-in `uart_reg_pkg.sv` and `uart_reg_top.sv`. dvsim
loaded the UART simulation configuration and listed its tests/regressions. A
matrix `--setup-only` job for `lowrisc:ip:uart:0.1` completed through native
FuseSoC/Edalize with status `SETUP_ONLY`; its metadata records the clean source
revision, Python 3.13.15/arm64, FuseSoC 2.4.5, and the compiler fingerprint
above.

These focused results validate the native migration, not full-corpus parity.
The frozen full OpenTitan and Caliptra matrices remain historical until their
bounded ARM64 reruns complete.

## Robustness and security notes

- The cap stopped the parallel build pressure; this was not an Icarus memory
  leak or a cybersecurity incident.
- The UVM DPI build emitted deprecation warnings for upstream UVM `sprintf`
  calls. No overflow, corruption, or exploitation was observed; the dependency
  retains its existing maximum-length checks and was not edited here.
- Tracked x86_64 `.dSYM` payloads and host-specific Python bytecode were
  removed, and `.dSYM`, `__pycache__`, and interrupted `.o.tmp` artifacts are
  ignored so they cannot silently cross architectures again.
