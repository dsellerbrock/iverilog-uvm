#!/bin/bash
#SBATCH --job-name=a3-c21b-limit
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=slurm-%j.out
set -u

RUN_DIR="$(pwd)"
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
IVL="$IVL_ROOT/bin/iverilog"
VVP="$IVL_ROOT/bin/vvp"
STATUS=0

mkdir -p raw build scratch/2017 scratch/2023
sha256sum input/*.sv "$IVL" "$VVP" > sha256.txt

for EDITION in 2017 2023; do
  for PROBE in p21_evcd_limit p21_evcd_drv; do
    timeout 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
      -o "build/${PROBE}_${EDITION}.vvp" "input/${PROBE}.sv" \
      > "raw/compile-${PROBE}-${EDITION}.stdout" \
      2> "raw/compile-${PROBE}-${EDITION}.stderr"
    COMPILE_RC=$?
    echo "$COMPILE_RC" > "raw/compile-${PROBE}-${EDITION}.rc"
    if [ "$COMPILE_RC" -ne 0 ]; then STATUS=1; continue; fi

    (cd "scratch/$EDITION" && timeout 30s "$VVP" \
      "$RUN_DIR/build/${PROBE}_${EDITION}.vvp") \
      > "$RUN_DIR/raw/run-${PROBE}-${EDITION}.stdout" \
      2> "$RUN_DIR/raw/run-${PROBE}-${EDITION}.stderr"
    RUN_RC=$?
    echo "$RUN_RC" > "raw/run-${PROBE}-${EDITION}.rc"
    if [ "$RUN_RC" -ne 0 ]; then STATUS=1; fi
    for FILE in lim.evcd control.evcd drv.evcd; do
      if [ -f "scratch/$EDITION/$FILE" ]; then
        cp "scratch/$EDITION/$FILE" "raw/${FILE%.evcd}-${EDITION}.evcd"
        wc -l -c "scratch/$EDITION/$FILE" \
          > "raw/size-${FILE%.evcd}-${EDITION}.txt"
      fi
    done
  done
done

for EDITION in 2017 2023; do
  for PROBE in p21_evcd_limit p21_evcd_drv; do
    echo "--- -g$EDITION $PROBE compile_rc=$(cat raw/compile-$PROBE-$EDITION.rc) run_rc=$(cat raw/run-$PROBE-$EDITION.rc 2>/dev/null || echo not-run) ---"
    cat "raw/run-$PROBE-$EDITION.stdout" 2>/dev/null || true
    cat "raw/run-$PROBE-$EDITION.stderr" 2>/dev/null || true
  done
done
exit "$STATUS"
