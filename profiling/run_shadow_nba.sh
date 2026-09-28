#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test -e vvp.conf || ln -s tgt-vvp/vvp.conf vvp.conf
test -e vvp.tgt || ln -s tgt-vvp/vvp.tgt vvp.tgt

IVL_SHADOW_NBA_CERTIFY=1 driver/iverilog -B. -BMvpi -BPivlpp -g2012 -s tb \
  -o profiling/shadow_nba.vvp profiling/shadow_nba_tb.sv
rg -q '\.thread T_[0-9]+, \$shadow_nba;' profiling/shadow_nba.vvp
IVL_SHADOW_NBA_CERTIFY=0 driver/iverilog -B. -BMvpi -BPivlpp -g2012 -s tb \
  -o profiling/shadow_nba_uncertified.vvp profiling/shadow_nba_tb.sv
if rg -q '\$shadow_nba' profiling/shadow_nba_uncertified.vvp; then
  echo 'compiler certification was not opt-in' >&2
  exit 1
fi

iverilog-vpi -o nba_vpi_order_cb.vpi profiling/nba_vpi_order_cb.c
vvp/vvp -M . -m nba_vpi_order_cb profiling/shadow_nba.vvp \
  > profiling/shadow_nba.serial.actual
IVL_SHADOW_NBA=1 IVL_SHADOW_NBA_TRACE=1 vvp/vvp -M . \
  -m nba_vpi_order_cb profiling/shadow_nba.vvp \
  > profiling/shadow_nba.shadow.actual 2> profiling/shadow_nba.shadow.trace
IVL_SHADOW_NBA=1 vvp/vvp -M . -m nba_vpi_order_cb \
  profiling/shadow_nba_uncertified.vvp > profiling/shadow_nba.uncertified.actual
diff -u profiling/shadow_nba.expected profiling/shadow_nba.serial.actual
diff -u profiling/shadow_nba.expected profiling/shadow_nba.shadow.actual
diff -u profiling/shadow_nba.expected profiling/shadow_nba.uncertified.actual
test "$(rg -c 'SHADOW_NBA time=.*intents=2' profiling/shadow_nba.shadow.trace)" = 2

for top in tb_function tb_delay tb_vpi; do
  IVL_SHADOW_NBA_CERTIFY=1 driver/iverilog -B. -BMvpi -BPivlpp -g2012 -s "$top" \
    -o "profiling/shadow_nba_reject_$top.vvp" profiling/shadow_nba_reject_tb.sv
  if rg -q '\$shadow_nba' "profiling/shadow_nba_reject_$top.vvp"; then
    echo "$top was incorrectly certified" >&2
    exit 1
  fi
done
if IVL_SHADOW_NBA_CERTIFY=1 driver/iverilog -B. -BMvpi -BPivlpp -g2012 \
    -s tb_nested_wait -o profiling/shadow_nba_reject_nested.vvp \
    profiling/shadow_nba_reject_tb.sv > profiling/shadow_nba_reject_nested.log 2>&1; then
  echo 'nested wait unexpectedly elaborated in always_ff' >&2
  exit 1
fi
rg -q 'event control is not allowed.*always_ff' profiling/shadow_nba_reject_nested.log
