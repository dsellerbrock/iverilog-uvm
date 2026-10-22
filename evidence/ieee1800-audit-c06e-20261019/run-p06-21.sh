#!/usr/bin/env bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
D=tests/1800_audit/c06
OUT=evidence/ieee1800-audit-c06e-20261019/attempt-01
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
mkdir -p "$OUT"
printf 'HOST: %s\nAUDIT CHECKOUT HEAD: %s\nCOMPILER SOURCE COMMIT: b9441bafbdb0b6b7413c09e0381845e69481391b\n' "$(uname -a)" "$(git rev-parse HEAD)"
shasum -a 256 "$IVL" "$VVP"
for g in 2017 2023; do
  src="$D/p06_21a_lifetime.sv"
  base=p06_21a_lifetime
  exe="$OUT/$base.$g.vvp"
  log="$OUT/$base.$g.compile.log"
  python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "$src" >"$log" 2>&1
  rc=$?
  printf '\n%s -g%s compile_rc=%s\n' "$base" "$g" "$rc"
  cat "$log"
  if [ -f "$exe" ]; then
    run="$OUT/$base.$g.run.log"
    python3 scripts/run_with_timeout.py 60 -- "$VVP" "$exe" >"$run" 2>&1
    rc=$?
    printf '%s -g%s run_rc=%s\n' "$base" "$g" "$rc"
    cat "$run"
  fi
  for src in "$D"/neg/n06_21_*.sv; do
    base=$(basename "$src" .sv)
    exe="$OUT/$base.$g.vvp"
    log="$OUT/$base.$g.compile.log"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "$src" >"$log" 2>&1
    rc=$?
    printf '\n%s -g%s compile_rc=%s\n' "$base" "$g" "$rc"
    cat "$log"
  done
done
