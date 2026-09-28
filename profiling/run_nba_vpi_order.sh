#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test -e vvp.conf || ln -s tgt-vvp/vvp.conf vvp.conf
test -e vvp.tgt || ln -s tgt-vvp/vvp.tgt vvp.tgt
driver/iverilog -B. -BMvpi -BPivlpp -g2012 -s tb \
  -o profiling/nba_vpi_order.vvp profiling/nba_vpi_order_tb.sv
iverilog-vpi -o nba_vpi_order_cb.vpi profiling/nba_vpi_order_cb.c
vvp/vvp -M . -m nba_vpi_order_cb profiling/nba_vpi_order.vvp > profiling/nba_vpi_order.actual
diff -u profiling/nba_vpi_order.expected profiling/nba_vpi_order.actual
