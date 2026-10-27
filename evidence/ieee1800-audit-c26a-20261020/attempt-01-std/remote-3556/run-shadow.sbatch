#!/bin/bash
#SBATCH --job-name=a3-c26a-shadow
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
  timeout 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$EDITION" \
    -o "build/p26_07_std_shadow_$EDITION.vvp" input/p26_07_std_shadow.sv \
    > "raw/compile-$EDITION.stdout" 2> "raw/compile-$EDITION.stderr"
  echo "$?" > "raw/compile-$EDITION.rc"
  if [ "$(cat raw/compile-$EDITION.rc)" -eq 0 ]; then
    (cd "scratch/$EDITION" && timeout 30s "$VVP" \
      "$RUN_DIR/build/p26_07_std_shadow_$EDITION.vvp") \
      > "$RUN_DIR/raw/run-$EDITION.stdout" 2> "$RUN_DIR/raw/run-$EDITION.stderr"
    echo "$?" > "raw/run-$EDITION.rc"
  fi
done

for EDITION in 2017 2023; do
  echo "--- -g$EDITION ---"
  cat "raw/compile-$EDITION.rc" "raw/compile-$EDITION.stdout" "raw/compile-$EDITION.stderr" 2>/dev/null || true
  cat "raw/run-$EDITION.rc" "raw/run-$EDITION.stdout" "raw/run-$EDITION.stderr" 2>/dev/null || true
done
exit 0
