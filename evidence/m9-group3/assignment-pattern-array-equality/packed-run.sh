#!/bin/bash
set -e
D=/tmp/a3_728_edge.HhFx2J
I=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/local-install-p1/bin/iverilog
V=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/local-install-p1/bin/vvp
T=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-m9-p1-1036-20261026/scripts/run_with_timeout.py
for g in 2017 2023; do
 python3 "$T" 120 -- "$I" -g"$g" -s top -o "$D/packed-$g.vvp" "$D/packed_types.sv"
 echo "== -g$g =="
 python3 "$T" 120 -- "$V" "$D/packed-$g.vvp"
done
