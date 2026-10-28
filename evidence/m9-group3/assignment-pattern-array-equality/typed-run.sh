#!/bin/bash
set +e
D=/tmp/a3_728_edge.HhFx2J
I=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/local-install-p1/bin/iverilog
V=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/local-install-p1/bin/vvp
T=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/scripts/run_with_timeout.py
for g in 2017 2023; do
  echo "== sv_eq -g$g"
  python3 "$T" 120 -- "$I" -g"$g" -o "$D/se$g" "$D/sv_eq.sv" 2>&1
  rc=$?; echo "compile_rc=$rc"
  if [ "$rc" -eq 0 ]; then python3 "$T" 120 -- "$V" "$D/se$g"; fi
  echo "== untyped -g$g"
  python3 "$T" 120 -- "$I" -g"$g" -o /dev/null "$D/untyped.sv" 2>&1
  echo "compile_rc=$?"
done
