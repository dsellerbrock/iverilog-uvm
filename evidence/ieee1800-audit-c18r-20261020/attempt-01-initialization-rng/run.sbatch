#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-initrng
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/1800-c18r-20261020-01/logs/%x-%j.out

set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/1800-c18r-20261020-01
TOOLCHAIN=/home/dsell/toolchains/iverilog-fb584a25-20261020
SRC="$RUN_DIR/input/p18_14_initialization_rng.sv"
RESULT="$RUN_DIR/result.txt"

mkdir -p "$RUN_DIR/logs"
printf 'source_head=fb584a251dd4cc91e56a75be662ccd5ee05c64e9\n' > "$RESULT"
printf 'probe_sha256=%s\n' "$(sha256sum "$SRC" | cut -d ' ' -f1)" >> "$RESULT"
"$TOOLCHAIN/bin/iverilog" -V > "$RUN_DIR/logs/iverilog-version.txt" 2>&1
"$TOOLCHAIN/bin/vvp" -V > "$RUN_DIR/logs/vvp-version.txt" 2>&1

for edition in 2017 2023; do
  timeout -s TERM -k 2s 30s "$TOOLCHAIN/bin/iverilog" -g"$edition" -s test \
    -o "$RUN_DIR/test-$edition.vvp" "$SRC" \
    > "$RUN_DIR/logs/compile-$edition.stdout" \
    2> "$RUN_DIR/logs/compile-$edition.stderr"
  timeout -s TERM -k 2s 30s "$TOOLCHAIN/bin/vvp" "$RUN_DIR/test-$edition.vvp" \
    > "$RUN_DIR/logs/run-$edition.stdout" \
    2> "$RUN_DIR/logs/run-$edition.stderr"
  grep -Fxq 'PASS initialization RNG stability' "$RUN_DIR/logs/run-$edition.stdout"
  printf 'edition_%s=PASS\n' "$edition" >> "$RESULT"
done

printf 'probe=PASS\n' >> "$RESULT"
