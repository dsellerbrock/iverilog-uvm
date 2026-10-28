#!/bin/bash
set +e
D=/tmp/a3_728_edge.HhFx2J
I=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-svtests-qualified-if-20260813/local-install/bin/iverilog
for g in 2017 2023; do
 echo "== base 02ff255 -g$g typed patterns"
 python3 /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/scripts/run_with_timeout.py 120 -- "$I" -g"$g" -o "$D/base-$g" "$D/sv_eq.sv" 2>&1; echo "rc=$?"
 echo "== base 02ff255 -g$g untyped pattern"
 python3 /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/scripts/run_with_timeout.py 120 -- "$I" -g"$g" -o "$D/base-u-$g" "$D/untyped.sv" 2>&1; echo "rc=$?"
done
