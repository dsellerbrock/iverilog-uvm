#!/usr/bin/env bash
set -uo pipefail

IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c06
E=evidence/ieee1800-audit-c06b-20261019/step2-3
mkdir -p "$E"

sed '/arr\[1\]/d; s/module p06_19b_enum_methods;/module p06_19b2_enum_methods_noarr;/' \
  "$D/p06_19b_enum_methods.sv" > "$D/p06_19b2_enum_methods_noarr.sv"

for g in 2017 2023; do
  b=p06_19b2_enum_methods_noarr
  o="$E/$b.$g"
  python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$D/$b.sv" >"$o.compile.log" 2>&1
  rc=$?
  echo "== $b -g$g compile_rc=$rc"
  cat "$o.compile.log"
  if [ -f "$o.vvp" ]; then
    python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1
    rc=$?
    echo "run_rc=$rc"
    cat "$o.run.log"
  fi
done

if command -v slang >/dev/null 2>&1; then
  slang --version
  for f in "$D"/r06_19l_*.sv; do
    b=$(basename "$f" .sv)
    o="$E/$b.slang-2017"
    python3 scripts/run_with_timeout.py 60 -- slang --std 1800-2017 "$f" >"$o.log" 2>&1
    rc=$?
    echo "== slang -g2017 $b compile_rc=$rc"
    head -10 "$o.log"
  done
else
  echo "slang not installed"
fi
