#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
iverilog -g2012 -s tb -o profiling/nba_vpi_order.vvp profiling/nba_vpi_order_tb.sv
iverilog-vpi -o nba_vpi_order_cb.vpi profiling/nba_vpi_order_cb.c
vvp/vvp -M . -m nba_vpi_order_cb profiling/nba_vpi_order.vvp > profiling/nba_vpi_order.actual
diff -u profiling/nba_vpi_order.expected profiling/nba_vpi_order.actual
