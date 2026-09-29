#!/bin/bash
# sweep_one.sh JSON: differential check of one ivtest program, interpreter
# vs native. R is the repository root (its local-install holds the compiler
# and VPI modules, R/vvp/vvp is a runtime built with runtime.diff); WORK
# is scratch space. Prints one line: NAME SAME|DIFF|RC_DIFF|NONE|... .
HERE=$(cd "$(dirname "$0")" && pwd)
R=${R:-$(cd "$HERE/../.." && pwd)}
WORK=${WORK:-/tmp/native-sweep}
IV=$R/local-install/bin/iverilog
V=$R/vvp/vvp; M="-M $R/local-install/lib/ivl"
j=$1; name=$(basename $j .json)
IFS=$'\t' read -r type src args vargs < <(python3 -c "
import json,sys; j=json.load(open('$j'))
print('\t'.join([str(j.get('type')), str(j.get('source')), ' '.join(j.get('iverilog-args',[])) or '-', ' '.join(j.get('vvp-args',[])) or '-']))")
[ "$type" = normal ] && [ "$vargs" = - ] || exit 0
[ "$args" = - ] && args=""
W=$WORK/$name; mkdir -p $W
cd $R/ivtest
timeout 60 $IV $args -o $W/t.vvp ivltests/$src > /dev/null 2>&1 || { echo "$name COMPILE_FAIL"; exit 0; }
python3 $HERE/native_gen4.py $W/t.vvp $W/n.vvp $W/n.cc > $W/gen.txt 2>&1 || { echo "$name GEN_FAIL"; exit 0; }
nt=$(tail -1 $W/gen.txt | awk '{print $1}')
[ "$nt" = 0 ] && { echo "$name NONE"; exit 0; }
g++ -O1 -shared -fPIC -o $W/n.so $W/n.cc > $W/cc.txt 2>&1 || { echo "$name CXX_FAIL"; exit 0; }
timeout 60 $V $M -n $W/t.vvp > $W/i.txt 2> $W/ierr.txt; ri=$?
VVP_NATIVE_STATS=1 VVP_NATIVE_SO=$W/n.so timeout 60 $V $M -n $W/n.vvp > $W/n.txt 2> $W/nerr.txt; rn=$?
runs=$(awk '/runs/{r+=$6} END{print r+0}' $W/nerr.txt)
grep -v "^vvp native:\|^deopt fn" $W/nerr.txt > $W/nerr2.txt
# compare stdout+stderr of both (interp merged; native merged after)
if [ $ri != $rn ]; then echo "$name RC_DIFF i=$ri n=$rn runs=$runs"
elif cmp -s $W/i.txt $W/n.txt && cmp -s $W/ierr.txt $W/nerr2.txt; then echo "$name SAME runs=$runs"; rm -rf $W
else echo "$name DIFF runs=$runs"; fi
