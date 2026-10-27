#!/usr/bin/env bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
D=tests/1800_audit/c06
E=evidence/ieee1800-audit-c06h-20261019/attempt-01
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
printf 'HOST: %s\nCHECKOUT: %s\nSOURCE: b9441bafbdb0b6b7413c09e0381845e69481391b\n' "$(uname -a)" "$(git rev-parse HEAD)"
shasum -a 256 "$IVL" "$VVP"
for g in 2017 2023; do
  for f in "$D/p06_11a_integer_real.sv" "$D/p06_14a_void_chandle.sv"; do b=$(basename "$f" .sv); o="$E/$b.$g"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" > "$o.compile.log" 2>&1; rc=$?
    printf '\n== %s g%s compile rc=%s\n' "$b" "$g" "$rc"; head -8 "$o.compile.log"
    if [ -f "$o.vvp" ]; then python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; rc=$?; printf 'run rc=%s\n' "$rc"; head -10 "$o.run.log"; fi
  done
  for f in "$D"/neg/n06_1[234]_*.sv; do b=$(basename "$f" .sv); o="$E/$b.$g"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" > "$o.compile.log" 2>&1; rc=$?
    printf '%s g%s rc=%s\n' "$b" "$g" "$rc"; head -2 "$o.compile.log"
  done
done
for k in 'integer type' 'integer data type' 'real conversion' 'real rounding' shortreal realtime chandle void 'tagged union void' 'posedge real' 'real index'; do
  slug=$(printf '%s' "$k" | tr -c 'A-Za-z0-9' '_')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$k" --limit 40 > "$E/dedupe_$slug.txt"
done
cat "$E"/dedupe_*.txt | sort -u > "$E/dedupe-unique.txt"
printf '\n--- dedupe unique results ---\n'; cat "$E/dedupe-unique.txt"
