#!/bin/bash
#SBATCH --job-name=a3-c26a-min
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

mkdir -p raw build scratch/2017 scratch/2023
sha256sum input/*.sv "$IVL" "$VVP" > sha256.txt

for EDITION in 2017 2023; do
  for PROBE in p26_07_std n26_07_std_qualified_types p26_07_std_implicit_types p26_07_std_randomize_only n26_07_package_std p21_evcd_limit; do
    timeout 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
      -o "build/${PROBE}_${EDITION}.vvp" "input/${PROBE}.sv" \
      > "raw/compile-${PROBE}-${EDITION}.stdout" \
      2> "raw/compile-${PROBE}-${EDITION}.stderr"
    COMPILE_RC=$?
    echo "$COMPILE_RC" > "raw/compile-${PROBE}-${EDITION}.rc"
    if [ "$COMPILE_RC" -eq 0 ]; then
      mkdir -p "scratch/$EDITION/$PROBE"
      (cd "scratch/$EDITION/$PROBE" && timeout 30s "$VVP" \
        "$RUN_DIR/build/${PROBE}_${EDITION}.vvp") \
        > "$RUN_DIR/raw/run-${PROBE}-${EDITION}.stdout" \
        2> "$RUN_DIR/raw/run-${PROBE}-${EDITION}.stderr"
      echo "$?" > "raw/run-${PROBE}-${EDITION}.rc"
      for FILE in lim.evcd control.evcd; do
        if [ -f "scratch/$EDITION/$PROBE/$FILE" ]; then
          cp "scratch/$EDITION/$PROBE/$FILE" \
            "raw/${PROBE}-${EDITION}-${FILE}"
        fi
      done
    fi
  done
done

for EDITION in 2017 2023; do
  for PROBE in p26_07_std n26_07_std_qualified_types p26_07_std_implicit_types p26_07_std_randomize_only n26_07_package_std p21_evcd_limit; do
    echo "--- -g$EDITION $PROBE compile_rc=$(cat raw/compile-$PROBE-$EDITION.rc) run_rc=$(cat raw/run-$PROBE-$EDITION.rc 2>/dev/null || echo not-run) ---"
    cat "raw/compile-$PROBE-$EDITION.stdout" "raw/compile-$PROBE-$EDITION.stderr" 2>/dev/null || true
    cat "raw/run-$PROBE-$EDITION.stdout" "raw/run-$PROBE-$EDITION.stderr" 2>/dev/null || true
  done
done
exit 0
