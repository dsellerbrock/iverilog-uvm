#!/bin/bash
# timeit.sh: interleaved user-CPU pairs (base 7a04009f vs new), 3 per workload,
# alternating order; prints ratios, median, and output equality.
SP=<scratch>
cd $SP/wl/timed
BV="$SP/baselib/vvp_base -M /home/user/iverilog-uvm/local-install/lib/ivl"
NV=/home/user/iverilog-uvm/local-install/bin/vvp
one() { # $1 base|new  $2 workload
      local bin args plus
      if [ $1 = base ]; then bin=$BV; else bin=$NV; fi
      case $2 in uvm*) args="-d /tmp/uvm_dpi_iv.vpi"; plus="+N=200";; *) args=""; plus="";; esac
      { TIMEFORMAT=%U; time $bin -n $args ${1}_$2.vvp $plus 2>/dev/null \
            | grep -v "finish called\|uvm_root.svh(4\|RELNOTES\|^ *$" > out_${1}_$2.txt; } 2>&1
}
for w in ${WORKLOADS:-sha pico a2b uvmnone uvm}; do
      rs=""
      for i in 1 2 3; do
            if [ $((i % 2)) = 1 ]; then b=$(one base $w); n=$(one new $w)
            else n=$(one new $w); b=$(one base $w); fi
            rs="$rs $(echo "scale=3; $b / $n" | bc)"
            echo "  $w pair$i base=$b new=$n"
      done
      med=$(echo $rs | tr ' ' '\n' | sort -n | sed -n 2p)
      cmp -s out_base_$w.txt out_new_$w.txt && eq=same || eq=DIFFERENT
      echo "$w ratios:$rs median=$med output=$eq"
done
