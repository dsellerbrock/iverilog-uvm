#!/bin/bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c20
E=evidence/ieee1800-audit-c20a-20261019/attempt-04-corrected-generators
printf '%s\n' "$(uname -a)" > "$E/host.txt"
git rev-parse HEAD > "$E/head.txt"
git status --short > "$E/git-status.txt"
shasum -a 256 "$IVL" "$VVP" > "$E/toolchain-sha256.txt"
shasum -a 256 "$D/p20_03b_time_conv.sv" "$D"/r20_05_k_*.sv "$D/r20_02_exit_in_program.sv "$D/r20_02_exit.sv > "$E/source-sha256.txt"
for g in 2017 2023; do
  for f in "$D/p20_03b_time_conv.sv" "$D"/r20_05_k_*.sv "$D/r20_02_exit_in_program.sv "$D/r20_02_exit.sv; do
    name=$(basename "$f" .sv); o="$E/$name.$g"
    if ~/codex-supervisor/localrun 10 "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1; then
      printf '== %s g%s compile rc=0\n' "$name" "$g"
      if ~/codex-supervisor/localrun 10 "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then printf '%s g%s run rc=0\n' "$name" "$g"; rg -v '^\s*[0-9.]+ real|^\s*[0-9]+ ' "$o.run.log" || true; else rc=$?; printf '%s g%s run rc=%s\n' "$name" "$g" "$rc"; cat "$o.run.log"; fi
    else rc=$?; printf '== %s g%s compile rc=%s\n' "$name" "$g" "$rc"; rg 'error:|sorry:|warning:' "$o.compile.log" || true; fi
  done
done
