#!/bin/sh
set -eu
lane=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-doe-root-cause-20260923/disposable
export PATH=/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-doe-scan-v5052-20260923/aliases:$PATH
export CALIPTRA_ROOT=$lane/source
export CALIPTRA_WORKSPACE=$lane
export CALIPTRA_PRIM_ROOT=$lane/source/src/caliptra_prim_generic
export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
export CALIPTRA_AXI4PC_DIR=$lane/source/src/integration/tb
make -C "$lane/run" -f "$lane/source/tools/scripts/Makefile" \
  TESTNAME=smoke_test_doe_scan CALIPTRA_INTERNAL_TRNG=1 PLAYBOOK_RANDOM_SEED=1 \
  'BUILD_CFLAGS=-std=gnu11 -O2' \
  'VERILATOR=/Users/danielellerbrock/projects/iverilog_uvm/evidence/verilator-midwindow-doe-20260923/install-5052/bin/verilator -Wno-MISINDENT' \
  "CFLAGS=-std=gnu++20 -I$lane/source/src/integration/test_suites/libs/jtagdpi/ -I$lane/source/src/integration/test_suites/libs/tcp_server/" \
  verilator-build
