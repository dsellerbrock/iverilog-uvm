#!/bin/bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12b-20261019/attempt-01-loop-jump-probes
printf '%s\n' "$(uname -a)" > "$E/host.txt"
git rev-parse HEAD > "$E/head.txt"
git status --short > "$E/git-status.txt"
shasum -a 256 "$IVL" "$VVP" > "$E/toolchain-sha256.txt"
shasum -a 256 "$D/p12_07a_loops_jumps.sv" "$D"/neg/n12_07_mixed_decl.sv "$D"/neg/n12_07_foreach_same_name.sv "$D"/neg/n12_07_foreach_too_many.sv "$D"/neg/n12_08_break_outside.sv "$D"/neg/n12_08_continue_fork.sv "$D"/neg/n12_08_return_outside.sv "$D"/neg/n12_08_return_value_task.sv > "$E/source-sha256.txt"
for g in 2017 2023; do
  o="$E/p12d.$g"
  if python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -s p12d -o "$o.vvp" "$D/p12_07a_loops_jumps.sv" >"$o.compile.log" 2>&1; then
    printf 'g%s compile rc=0\n' "$g"
    if python3 scripts/run_with_timeout.py 180 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then cat "$o.run.log"; else rc=$?; printf 'g%s run rc=%s\n' "$g" "$rc"; cat "$o.run.log"; fi
  else rc=$?; printf 'g%s compile rc=%s\n' "$g" "$rc"; head -4 "$o.compile.log"; fi
  for f in "$D"/neg/n12_07_*.sv "$D"/neg/n12_08_*.sv; do
    name=$(basename "$f")
    if python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -o /dev/null "$f" >"$E/$name.g$g.log" 2>&1; then printf '%s g%s accepted rc=0\n' "$name" "$g"; else rc=$?; printf '%s g%s rejected rc=%s\n' "$name" "$g" "$rc"; fi
  done
done
