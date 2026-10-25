#!/bin/bash
#SBATCH --job-name=a3-c35b-dpi
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
CC=/usr/bin/gcc
DPI_INCLUDE="$IVL_ROOT/include/iverilog"
STATUS=0

mkdir -p raw build scratch/2017 scratch/2023
sha256sum input/* "$IVL" "$VVP" "$DPI_INCLUDE/svdpi.h" "$CC" > sha256.txt
"$IVL" -V > raw/iverilog-version.txt 2>&1
"$VVP" -V > raw/vvp-version.txt 2>&1
"$CC" --version | head -n 1 > raw/gcc-version.txt
printf 'A1 9\nT1 5\nT2 1 16\nF1 1\n' > expected.txt

for EDITION in 2017 2023; do
  (cd "scratch/$EDITION" && timeout 30s "$IVL" \
    -B "$IVL_ROOT/lib/ivl" -g"$EDITION" -o p35_task.out \
    "$RUN_DIR/input/p35_task.sv") \
    > "$RUN_DIR/raw/compile-$EDITION.stdout" \
    2> "$RUN_DIR/raw/compile-$EDITION.stderr"
  COMPILE_RC=$?
  echo "$COMPILE_RC" > "raw/compile-$EDITION.rc"
  if [ "$COMPILE_RC" -ne 0 ]; then STATUS=1; continue; fi

  cp "scratch/$EDITION/p35_task.out.dpiexport.c" \
    "raw/p35_task-$EDITION.dpiexport.c"
  (cd "scratch/$EDITION" && timeout 30s "$CC" -shared -fPIC \
    -I "$DPI_INCLUDE" -o libdpi.so "$RUN_DIR/input/dpi_task.c" \
    p35_task.out.dpiexport.c) \
    > "$RUN_DIR/raw/link-$EDITION.stdout" \
    2> "$RUN_DIR/raw/link-$EDITION.stderr"
  LINK_RC=$?
  echo "$LINK_RC" > "raw/link-$EDITION.rc"
  if [ "$LINK_RC" -ne 0 ]; then STATUS=1; continue; fi
  cp "scratch/$EDITION/libdpi.so" "raw/libdpi-$EDITION.so"

  (cd "scratch/$EDITION" && timeout 30s "$VVP" -d ./libdpi.so \
    ./p35_task.out) \
    > "$RUN_DIR/raw/run-$EDITION.stdout" \
    2> "$RUN_DIR/raw/run-$EDITION.stderr"
  RUN_RC=$?
  echo "$RUN_RC" > "raw/run-$EDITION.rc"
  if [ "$RUN_RC" -ne 0 ] || ! diff -u "$RUN_DIR/expected.txt" \
      "$RUN_DIR/raw/run-$EDITION.stdout"; then STATUS=1; fi

  (cd "scratch/$EDITION" && timeout 30s "$IVL" \
    -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
    -o n35_dup_c_identifier.out "$RUN_DIR/input/n35_dup_c_identifier.sv") \
    > "$RUN_DIR/raw/negative-$EDITION.stdout" \
    2> "$RUN_DIR/raw/negative-$EDITION.stderr"
  NEGATIVE_RC=$?
  echo "$NEGATIVE_RC" > "raw/negative-$EDITION.rc"
  if [ "$NEGATIVE_RC" -eq 0 ]; then STATUS=1; fi
done

for EDITION in 2017 2023; do
  echo "--- -g$EDITION ---"
  for STEP in compile link run negative; do
    echo "$STEP rc: $(cat "raw/$STEP-$EDITION.rc" 2>/dev/null || echo missing)"
    cat "raw/$STEP-$EDITION.stdout" "raw/$STEP-$EDITION.stderr" 2>/dev/null || true
  done
done
exit "$STATUS"
