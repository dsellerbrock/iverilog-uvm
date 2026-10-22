#!/bin/bash
set -u
D=tests/1800_audit/c20/q
E=evidence/ieee1800-audit-c20c-20261019/attempt-04-isolated
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
printf '%s\n' "$(uname -a)" > "$E/host.txt"
git rev-parse HEAD > "$E/head.txt"
git status --short > "$E/git-status.txt"
shasum -a 256 "$IVL" "$VVP" > "$E/toolchain-sha256.txt"
shasum -a 256 "$D"/q_*.sv > "$E/source-sha256.txt"
printf 'generated probes: %s\n' "$(find "$D" -maxdepth 1 -name 'q_*.sv' | wc -l | tr -d ' ')" > "$E/summary.log"
for g in 2017 2023; do
  for f in "$D"/q_*.sv; do
    n=$(basename "$f" .sv); o="$E/$n.$g"
    if ~/codex-supervisor/localrun 10 "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1; then
      if ~/codex-supervisor/localrun 10 "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then
        line=$(rg '^Q ' "$o.run.log" || true)
        if [[ -n "$line" ]]; then printf '%s g%s run rc=0 %s\n' "$n" "$g" "$line" | tee -a "$E/summary.log"; else printf '%s g%s run rc=0 no Q line\n' "$n" "$g" | tee -a "$E/summary.log"; fi
      else rc=$?; printf '%s g%s run rc=%s\n' "$n" "$g" "$rc" | tee -a "$E/summary.log"; rg 'ERROR|FATAL|Q ' "$o.run.log" | tee -a "$E/summary.log" || true; fi
    else rc=$?; printf '%s g%s compile rc=%s\n' "$n" "$g" "$rc" | tee -a "$E/summary.log"; rg 'error:|sorry:|warning:' "$o.compile.log" | tee -a "$E/summary.log" || true; fi
  done
done
