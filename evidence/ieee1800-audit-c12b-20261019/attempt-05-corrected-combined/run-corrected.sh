#!/bin/bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12b-20261019/attempt-05-corrected-combined
printf '%s\n' "$(uname -a)" > "$E/host.txt"
git rev-parse HEAD > "$E/head.txt"
shasum -a 256 "$IVL" "$VVP" > "$E/toolchain-sha256.txt"
shasum -a 256 "$D/p12_07a_loops_jumps.sv" "$D/p12_07b_loops_jumps.sv" > "$E/source-sha256.txt"
for g in 2017 2023; do
  o="$E/p12d.$g"
  if ~/codex-supervisor/localrun 30 "$IVL" -g"$g" -s p12d -o "$o.vvp" "$D/p12_07b_loops_jumps.sv" >"$o.compile.log" 2>&1; then
    printf 'g%s compile rc=0\n' "$g"
    if ~/codex-supervisor/localrun 30 "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then rg '^(FAIL|RESULT)' "$o.run.log"; else rc=$?; printf 'g%s run rc=%s\n' "$g" "$rc"; cat "$o.run.log"; fi
  else rc=$?; printf 'g%s compile rc=%s\n' "$g" "$rc"; head -5 "$o.compile.log"; fi
done
