#!/usr/bin/env bash
#SBATCH --job-name=a3-c29-udp5
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
TOOLCHAIN=/home/dsell/toolchains/iverilog-fb584a25-20261020
IVL="$TOOLCHAIN/bin/iverilog"
VVP="$TOOLCHAIN/bin/vvp"
mkdir -p build results
echo "HOST=$(hostname)"
echo "TOOLCHAIN_SOURCE_COMMIT=fb584a251dd4cc91e56a75be662ccd5ee05c64e9"
sha256sum "$IVL" "$VVP"

for edition in 2017 2023; do
  timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s p29_more -o "build/p29_more-$edition.vvp" tests/p29_more.sv >"results/p29_more-$edition.compile.log" 2>&1
  timeout --signal=TERM --kill-after=5s 30s "$VVP" "build/p29_more-$edition.vvp" >"results/p29_more-$edition.out" 2>"results/p29_more-$edition.run.log"
  echo "--- p29_more -g$edition ---"
  cat "results/p29_more-$edition.out"
  diff -u expected.txt "results/p29_more-$edition.out"
done
