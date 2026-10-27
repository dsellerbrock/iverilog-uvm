#!/bin/bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
D=tests/1800_audit/c12/neg
E=evidence/ieee1800-audit-c12b-20261019/attempt-03-negative-recheck
printf '%s\n' "$(uname -a)" > "$E/host.txt"
git rev-parse HEAD > "$E/head.txt"
shasum -a 256 "$IVL" > "$E/toolchain-sha256.txt"
files=(n12_07_foreach_index_write.sv n12_07_foreach_same_name.sv n12_07_foreach_too_many.sv n12_07_for_scope_escape.sv n12_07_foreach_too_many_indices.sv n12_08_break_cross_fork.sv n12_08_continue_fork.sv)
for g in 2017 2023; do
  for name in "${files[@]}"; do
    f="$D/$name"
    out="$E/$name.g$g.log"
    if ~/codex-supervisor/localrun 10 "$IVL" -g"$g" -o /dev/null "$f" >"$out" 2>&1; then printf '%s g%s accepted rc=0\n' "$name" "$g"; else rc=$?; printf '%s g%s rejected rc=%s\n' "$name" "$g" "$rc"; fi
  done
done
shasum -a 256 "${files[@]/#/$D/}" > "$E/source-sha256.txt"
