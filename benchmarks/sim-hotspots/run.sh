#!/usr/bin/env bash
# Compare two vvp runtimes on the simulation hot-spot benchmarks.
#
# Usage: run.sh <reference-vvp> <candidate-vvp> [runs]
#
# Each benchmark is compiled once with the iverilog on PATH, run with both
# runtimes, and reported as the median wall time of RUNS runs (default 3).
# The full simulation output of both runtimes must be byte-identical; a
# mismatch is reported and makes the script exit nonzero. Benchmarks listed in
# SAMPLING_FIXED draw values that a pre-fix reference sampled non-uniformly, so
# their output is expected to differ from such a reference.
set -u
REF=${1:?reference vvp}
NEW=${2:?candidate vvp}
RUNS=${3:-3}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

UVM="$ROOT/uvm-core/src"
UVM_DPI="$ROOT/local-install/lib/ivl/uvm_dpi.vpi"
SAMPLING_FIXED=" randomize_dv_txn "

compile() {
      local name=$1
      case "$name" in
	  uvm_traffic)
	    iverilog -g2012 -I "$UVM" -o "$WORK/$name.vvp" \
		  "$UVM/uvm_pkg.sv" "$HERE/$name.sv" ;;
	  randomize_*)
	    iverilog -g2017 -s main -o "$WORK/$name.vvp" "$HERE/$name.sv" ;;
	  *)
	    iverilog -g2012 -o "$WORK/$name.vvp" "$HERE/$name.sv" ;;
      esac >"$WORK/$name.compile.log" 2>&1
}

run_once() { # vvp name out -> prints seconds
      local vvp=$1 name=$2 out=$3 dflags=""
      [ "$name" = uvm_traffic ] && dflags="-d $UVM_DPI"
      local t0 t1
      t0=$(date +%s.%N)
      "$vvp" -n $dflags "$WORK/$name.vvp" >"$out" 2>&1
      t1=$(date +%s.%N)
      echo "$t1 - $t0" | bc
}

median() { sort -n | awk '{v[NR]=$1} END {print v[int((NR+1)/2)]}'; }

status=0
printf '%-14s %10s %10s %8s %s\n' benchmark reference candidate speedup output
for name in rtl_pipe rtl_alu behav classq uvm_traffic randomize_z3 randomize_dv_txn; do
      if ! compile "$name"; then
	    echo "$name: compile failed (see $WORK/$name.compile.log)"
	    status=1
	    continue
      fi
      ref_times=() new_times=()
      for ((i = 0; i < RUNS; i++)); do
	    ref_times+=("$(run_once "$REF" "$name" "$WORK/$name.ref.out")")
	    new_times+=("$(run_once "$NEW" "$name" "$WORK/$name.new.out")")
      done
      r=$(printf '%s\n' "${ref_times[@]}" | median)
      n=$(printf '%s\n' "${new_times[@]}" | median)
      if cmp -s "$WORK/$name.ref.out" "$WORK/$name.new.out"; then
	    same=identical
      elif [[ "$SAMPLING_FIXED" == *" $name "* ]]; then
	    same="differs (uniform sampling fix)"
      else
	    same=DIFFERENT
	    status=1
      fi
      printf '%-14s %9.2fs %9.2fs %7.2fx %s\n' "$name" "$r" "$n" \
	    "$(echo "$r / $n" | bc -l)" "$same"
done
exit $status
