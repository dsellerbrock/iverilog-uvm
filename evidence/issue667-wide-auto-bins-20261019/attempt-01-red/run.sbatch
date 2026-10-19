#!/usr/bin/env bash
#SBATCH --job-name=a3-667-red
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue667-wide-auto-bins-20261019-red/logs/%x-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/issue667-wide-auto-bins-20261019-red
TOOLCHAIN=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
INPUT="$RUN_DIR/input/sv_covergroup_wide_auto_bins.v"
RESULTS="$RUN_DIR/results"
mkdir -p "$RESULTS"
printf 'source='; sha256sum "$INPUT"
printf 'iverilog='; sha256sum "$TOOLCHAIN/iverilog"
printf 'vvp='; sha256sum "$TOOLCHAIN/vvp"
"$TOOLCHAIN/iverilog" -V | head -n 1
for standard in 2017 2023; do
  set +e
  timeout --signal=TERM --kill-after=5 60 "$TOOLCHAIN/iverilog" \
    -g"$standard" -gno-icarus-misc -gno-xtypes -s test \
    -o "$RESULTS/wide-auto-$standard.vvp" "$INPUT" \
    >"$RESULTS/compile-$standard.log" 2>&1
  status=$?
  set -e
  printf 'IEEE %s compile exit=%s\n' "$standard" "$status"
  cat "$RESULTS/compile-$standard.log"
  if [ "$status" -eq 0 ]; then
    echo "expected the baseline compiler to reject wide automatic bins" >&2
    exit 1
  fi
done
echo 'RED reproduced in both IEEE modes.'
