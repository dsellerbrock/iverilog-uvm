#!/bin/bash
#SBATCH --job-name=a3-c26a-std
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
  timeout 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
    -o "build/p26_07_std_$EDITION.vvp" input/p26_07_std.sv \
    > "raw/compile-positive-$EDITION.stdout" \
    2> "raw/compile-positive-$EDITION.stderr"
  COMPILE_RC=$?
  echo "$COMPILE_RC" > "raw/compile-positive-$EDITION.rc"
  if [ "$COMPILE_RC" -ne 0 ]; then STATUS=1; continue; fi
  (cd "scratch/$EDITION" && timeout 30s "$VVP" \
    "$RUN_DIR/build/p26_07_std_$EDITION.vvp") \
    > "$RUN_DIR/raw/run-positive-$EDITION.stdout" \
    2> "$RUN_DIR/raw/run-positive-$EDITION.stderr"
  RUN_RC=$?
  echo "$RUN_RC" > "raw/run-positive-$EDITION.rc"
  if [ "$RUN_RC" -ne 0 ]; then STATUS=1; fi

  timeout 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
    -o "build/n26_07_package_std_$EDITION.vvp" input/n26_07_package_std.sv \
    > "raw/compile-negative-$EDITION.stdout" \
    2> "raw/compile-negative-$EDITION.stderr"
  NEG_RC=$?
  echo "$NEG_RC" > "raw/compile-negative-$EDITION.rc"
  if [ "$NEG_RC" -eq 0 ]; then
    (cd "scratch/$EDITION" && timeout 30s "$VVP" \
      "$RUN_DIR/build/n26_07_package_std_$EDITION.vvp") \
      > "$RUN_DIR/raw/run-negative-$EDITION.stdout" \
      2> "$RUN_DIR/raw/run-negative-$EDITION.stderr"
    echo "$?" > "raw/run-negative-$EDITION.rc"
  fi

  timeout 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
    -o "build/p21_evcd_limit_$EDITION.vvp" input/p21_evcd_limit.sv \
    > "raw/compile-limit-$EDITION.stdout" \
    2> "raw/compile-limit-$EDITION.stderr"
  LIMIT_COMPILE_RC=$?
  echo "$LIMIT_COMPILE_RC" > "raw/compile-limit-$EDITION.rc"
  if [ "$LIMIT_COMPILE_RC" -ne 0 ]; then STATUS=1; continue; fi
  (cd "scratch/$EDITION" && timeout 30s "$VVP" \
    "$RUN_DIR/build/p21_evcd_limit_$EDITION.vvp") \
    > "$RUN_DIR/raw/run-limit-$EDITION.stdout" \
    2> "$RUN_DIR/raw/run-limit-$EDITION.stderr"
  LIMIT_RUN_RC=$?
  echo "$LIMIT_RUN_RC" > "raw/run-limit-$EDITION.rc"
  if [ "$LIMIT_RUN_RC" -ne 0 ]; then STATUS=1; fi
  for FILE in lim.evcd control.evcd; do
    if [ -f "scratch/$EDITION/$FILE" ]; then
      cp "scratch/$EDITION/$FILE" "raw/${FILE%.evcd}-limit-$EDITION.evcd"
    fi
  done
done

for EDITION in 2017 2023; do
  for KIND in positive negative limit; do
    echo "--- $EDITION $KIND ---"
    cat "raw/compile-$KIND-$EDITION.rc" 2>/dev/null || true
    cat "raw/compile-$KIND-$EDITION.stdout" "raw/compile-$KIND-$EDITION.stderr" 2>/dev/null || true
    cat "raw/run-$KIND-$EDITION.rc" "raw/run-$KIND-$EDITION.stdout" "raw/run-$KIND-$EDITION.stderr" 2>/dev/null || true
  done
done
exit "$STATUS"
