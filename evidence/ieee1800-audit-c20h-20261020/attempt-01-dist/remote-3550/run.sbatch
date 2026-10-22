#!/bin/bash
#SBATCH --job-name=a3-c20h-dist
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
EDITION_STATUS=0

cd "$RUN_DIR"
mkdir -p oracle input raw build
sha256sum oracle/dist.c input/p20_15_dist.sv "$IVL" "$VVP" > sha256.txt

gcc -std=gnu89 -O0 -fwrapv oracle/dist.c -lm -o build/dist-oracle \
  > raw/gcc.stdout 2> raw/gcc.stderr
GCC_RC=$?
echo "$GCC_RC" > raw/gcc.rc
if [ "$GCC_RC" -ne 0 ]; then exit "$GCC_RC"; fi
build/dist-oracle > oracle.out 2> raw/oracle.stderr
ORACLE_RC=$?
echo "$ORACLE_RC" > raw/oracle.rc
if [ "$ORACLE_RC" -ne 0 ]; then exit "$ORACLE_RC"; fi

for EDITION in 2017 2023; do
  "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" -o "build/p20_15_dist_$EDITION.vvp" \
    input/p20_15_dist.sv > "raw/compile-$EDITION.stdout" 2> "raw/compile-$EDITION.stderr"
  COMPILE_RC=$?
  echo "$COMPILE_RC" > "raw/compile-$EDITION.rc"
  if [ "$COMPILE_RC" -ne 0 ]; then EDITION_STATUS=1; continue; fi
  timeout 30s "$VVP" "build/p20_15_dist_$EDITION.vvp" \
    > "raw/vvp-$EDITION.stdout" 2> "raw/vvp-$EDITION.stderr"
  VVP_RC=$?
  echo "$VVP_RC" > "raw/vvp-$EDITION.rc"
  if [ "$VVP_RC" -ne 0 ]; then EDITION_STATUS=1; continue; fi
  diff -u oracle.out "raw/vvp-$EDITION.stdout" > "raw/diff-$EDITION.txt"
  DIFF_RC=$?
  echo "$DIFF_RC" > "raw/diff-$EDITION.rc"
  if [ "$DIFF_RC" -ne 0 ]; then EDITION_STATUS=1; fi
done

cat oracle.out
for EDITION in 2017 2023; do
  echo "--- -g$EDITION ---"
  cat "raw/vvp-$EDITION.stdout"
  echo "compile_rc=$(cat raw/compile-$EDITION.rc) vvp_rc=$(cat raw/vvp-$EDITION.rc) diff_rc=$(cat raw/diff-$EDITION.rc 2>/dev/null || echo missing)"
done
exit "$EDITION_STATUS"
