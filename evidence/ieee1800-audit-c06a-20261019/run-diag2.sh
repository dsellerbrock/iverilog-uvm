#!/usr/bin/env bash
set -u
B=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin
MB=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue666-cast-20261019/local-install/bin
E=evidence/ieee1800-audit-c06a-20261019/diag2
run_one() {
  local label=$1
  local ivl=$2
  local vvp=$3
  local src=$4
  local g=$5
  local name=$6
  local out="$E/$name.$g"
  rm -f "$out.vvp"
  perl -e 'alarm 60; exec @ARGV' "$ivl" -g"$g" -o "$out.vvp" "$src" >"$out.compile.log" 2>&1
  local rc=$?
  echo "== $label $name -g$g compile_rc=$rc"
  cat "$out.compile.log"
  if [ -f "$out.vvp" ]; then
    perl -e 'alarm 60; exec @ARGV' "$vvp" -n "$out.vvp" >"$out.run.log" 2>&1
    rc=$?
    echo "run_rc=$rc"
    cat "$out.run.log"
  else
    echo "run_rc=not-run; no .vvp generated"
  fi
}
echo "HOST: $(uname -a)"
echo "BATCH_SOURCE: b9441bafbdb0b6b7413c09e0381845e69481391b"
echo "BATCH_IVL_SHA: $(shasum -a 256 "$B/iverilog")"
echo "BATCH_VVP_SHA: $(shasum -a 256 "$B/vvp")"
for g in 2017 2023; do
  for l in A B C D E; do run_one batch "$B/iverilog" "$B/vvp" "tests/1800_audit/c06/r06_16_diag_$l.sv" "$g" "batch_diag_$l"; done
done
echo "MAIN_ANCESTOR_SOURCE: fafa49958d71c38e7a0a110f6df90a931e92a4cf (contained in origin/main)"
echo "MAIN_ANCESTOR_IVL_SHA: $(shasum -a 256 "$MB/iverilog")"
echo "MAIN_ANCESTOR_VVP_SHA: $(shasum -a 256 "$MB/vvp")"
for g in 2017 2023; do
  for l in C D; do run_one main_ancestor "$MB/iverilog" "$MB/vvp" "tests/1800_audit/c06/r06_16_diag_$l.sv" "$g" "main_diag_$l"; done
done
