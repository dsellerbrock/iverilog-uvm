#!/bin/bash
# build.sh <base|new> <scale>: compile every workload into <v>_*.vvp.
# scale: "prof" (short, for callgrind) or "time" (long, for CPU timing).
set -e
SP=<scratch>
R=/home/user/iverilog-uvm
S=$SP/cr/src
v=$1; scale=$2
cd $SP/wl
if [ $v = base ]; then B="-B $SP/baselib/ivl"; else B=""; fi
IV="$R/local-install/bin/iverilog $B -g2012"
if [ $scale = prof ]; then NBLK=4; CYC=3000; A2B=8; else NBLK=400; CYC=300000; A2B=150; fi
$IV -DNBLK=$NBLK -o ${v}_sha.vvp tb_sha.sv $S/sha512/rtl/sha512_core.v \
    $S/sha512/rtl/sha512_w_mem.v $S/sha512/rtl/sha512_k_constants.v \
    $S/sha512/rtl/sha512_h_constants.v $S/sha256/rtl/sha256_core.v \
    $S/sha256/rtl/sha256_w_mem.v $S/sha256/rtl/sha256_k_constants.v
$IV -DCYC=$CYC -o ${v}_pico.vvp tb_pico.v $SP/picorv32/picorv32.v
$IV -DCYC=$A2B -o ${v}_a2b.vvp $SP/red/tb_a2b.sv $SP/red/abr_masked_A2B_conv.sv \
    $SP/red/abr_masked_full_adder.sv $SP/red/abr_masked_AND.sv
$IV -I $R/uvm-core/src -o ${v}_uvm.vvp $R/uvm-core/src/uvm_pkg.sv uvm_alu.sv 2>/dev/null
