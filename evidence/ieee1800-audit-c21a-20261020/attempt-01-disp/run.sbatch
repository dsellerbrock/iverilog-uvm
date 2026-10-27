#!/bin/bash
#SBATCH --job-name=a3-c21a-disp
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
sha256sum input/p21_disp_io.sv "$IVL" "$VVP" > sha256.txt

for EDITION in 2017 2023; do
  timeout 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
    -o "build/p21_disp_io_$EDITION.vvp" input/p21_disp_io.sv \
    > "raw/compile-$EDITION.stdout" 2> "raw/compile-$EDITION.stderr"
  COMPILE_RC=$?
  echo "$COMPILE_RC" > "raw/compile-$EDITION.rc"
  if [ "$COMPILE_RC" -ne 0 ]; then STATUS=1; continue; fi

  (cd "scratch/$EDITION" && timeout 30s "$VVP" \
    "$RUN_DIR/build/p21_disp_io_$EDITION.vvp") \
    > "$RUN_DIR/raw/run-$EDITION.stdout" 2> "$RUN_DIR/raw/run-$EDITION.stderr"
  RUN_RC=$?
  echo "$RUN_RC" > "raw/run-$EDITION.rc"
  if [ "$RUN_RC" -ne 0 ]; then STATUS=1; fi
  cp "scratch/$EDITION/p21_t.txt" "raw/p21_t-$EDITION.txt" 2>/dev/null || true
done

for EDITION in 2017 2023; do
  echo "--- -g$EDITION compile_rc=$(cat raw/compile-$EDITION.rc) run_rc=$(cat raw/run-$EDITION.rc 2>/dev/null || echo not-run) ---"
  cat "raw/run-$EDITION.stdout" 2>/dev/null || true
done
exit "$STATUS"
