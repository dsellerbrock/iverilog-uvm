#!/usr/bin/env bash
set -uo pipefail

IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c06
E=evidence/ieee1800-audit-c06b-20261019
mkdir -p "$D/neg" "$E"

echo "HOST: $(uname -a)"
echo "SOURCE COMMIT: b9441bafbdb0b6b7413c09e0381845e69481391b"
echo "IVERILOG: $IVL"
"$IVL" -V 2>&1 | head -2
shasum -a 256 "$IVL" "$VVP"

for g in 2017 2023; do
  for f in "$D"/p06_19?_*.sv; do
    b=$(basename "$f" .sv)
    o="$E/$b.$g"
    rm -f "$o.vvp"
    echo "== $b -g$g compile"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1
    rc=$?
    echo "compile_rc=$rc"
    cat "$o.compile.log"
    if [ -f "$o.vvp" ]; then
      python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1
      rc=$?
      echo "run_rc=$rc"
      cat "$o.run.log"
    else
      echo "run_rc=not-run; no .vvp generated"
    fi
  done
  for f in "$D"/neg/n06_19_*.sv; do
    b=$(basename "$f" .sv)
    o="$E/$b.$g"
    rm -f "$o.vvp"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1
    rc=$?
    echo "$b g$g compile_rc=$rc vvp_generated=$([ -f "$o.vvp" ] && echo yes || echo no)"
    head -5 "$o.compile.log"
  done
done

for k in enum "enum first" "enum next" "enum name" "enum range" "enum cast" "enum method" enumeration; do
  file=$(echo "$k" | tr ' ' '_')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$k" --limit 40 > "$E/dedupe_$file.txt"
done
cat "$E"/dedupe_*.txt | sort -u
