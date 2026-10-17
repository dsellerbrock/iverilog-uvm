#!/usr/bin/env bash
set -euo pipefail
ROOT=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue447-disable-iff
EVIDENCE=/Users/danielellerbrock/codex-supervisor/evidence/a3-m5-issue447-disable-iff-edge-20261015
PREFIX="$ROOT/local-install"
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/z3/include -I/opt/homebrew/opt/libffi/include ${CPPFLAGS:-}"
export LDFLAGS="-L/opt/homebrew/opt/z3/lib -L/opt/homebrew/opt/libffi/lib ${LDFLAGS:-}"
{
  date -u '+date=%Y-%m-%dT%H:%M:%SZ'
  hostname
  uname -a
  git -C "$ROOT" rev-parse HEAD
  git -C "$ROOT" status --short
  clang --version | head -n 1
  bison --version | head -n 1
  autoconf --version | head -n 1
} > "$EVIDENCE/environment.txt"
cd "$ROOT"
sh autoconf.sh > "$EVIDENCE/build.log" 2>&1
./configure --prefix="$PREFIX" >> "$EVIDENCE/build.log" 2>&1
make -j2 >> "$EVIDENCE/build.log" 2>&1
make install >> "$EVIDENCE/build.log" 2>&1
export PATH="$PREFIX/bin:$PATH"
(cd "$ROOT/ivtest" && perl ./vvp_reg.pl "$EVIDENCE/t0-legacy.list") > "$EVIDENCE/t0-legacy.log" 2>&1
(cd "$ROOT/ivtest" && python3 ./vvp_reg.py --strict "$EVIDENCE/t0-vvp.list") > "$EVIDENCE/t0-vvp.log" 2>&1
bash "$ROOT/ci/run-smoke.sh" > "$EVIDENCE/t0-smoke.log" 2>&1
(cd "$ROOT/ivtest" && perl ./vvp_reg.pl "$ROOT/ivtest/regress-sv_assert_multiclock_fixed_control-focus-legacy.list") > "$EVIDENCE/t1-legacy.log" 2>&1
(cd "$ROOT/ivtest" && python3 ./vvp_reg.py --strict "$ROOT/ivtest/regress-sv_assert_multiclock_fixed_control-focus-vvp.list") > "$EVIDENCE/t1-vvp.log" 2>&1
printf 'PASS: build, T0 issue cases, smoke, and T1 multiclock fixed-control focus\n' > "$EVIDENCE/result.txt"
make clean >/dev/null
rm -rf "$PREFIX"
