#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-12-case-r3
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-case-20261019-35
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-case-20261019-35/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-case-20261019-35
TOOLCHAIN=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
RESULTS="$RUN_DIR/results"
IVERILOG="$TOOLCHAIN/bin/iverilog"
VVP="$TOOLCHAIN/bin/vvp"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\nsource_head=27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e\ntoolchain_source=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/input"/*.sv "$IVERILOG" "$VVP" | tee "$RESULTS/sha256.txt"
set +e
timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$TOOLCHAIN/lib/ivl" -g2017 -gassertions -s test -o "$RESULTS/p16_12_16-2017.vvp" "$RUN_DIR/input/p16_12_16_case.sv" > "$RESULTS/p16_12_16-2017.compile.log" 2>&1
compile2017=$?
printf 'compile_exit=%s\n' "$compile2017" >> "$RESULTS/p16_12_16-2017.compile.log"
if test "$compile2017" -eq 0; then
  timeout --signal=TERM --kill-after=5s 120s "$VVP" -n "$RESULTS/p16_12_16-2017.vvp" > "$RESULTS/p16_12_16-2017.run.log" 2>&1
  run2017=$?
else run2017=NA; fi
timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$TOOLCHAIN/lib/ivl" -g2023 -gassertions -s test -o "$RESULTS/p16_12_16-2023.vvp" "$RUN_DIR/input/p16_12_16_case.sv" > "$RESULTS/p16_12_16-2023.compile.log" 2>&1
compile2023=$?
printf 'compile_exit=%s\n' "$compile2023" >> "$RESULTS/p16_12_16-2023.compile.log"
if test "$compile2023" -eq 0; then
  timeout --signal=TERM --kill-after=5s 120s "$VVP" -n "$RESULTS/p16_12_16-2023.vvp" > "$RESULTS/p16_12_16-2023.run.log" 2>&1
  run2023=$?
else run2023=NA; fi
set -e
printf 'compile2017=%s run2017=%s compile2023=%s run2023=%s\nfinished=%s\n' "$compile2017" "$run2017" "$compile2023" "$run2023" "$(date -Is)" >> "$RESULTS/metadata.txt"
if test "$compile2017" -ne 0 || test "$run2017" -ne 0 || test "$compile2023" -ne 0 || test "$run2023" -ne 0; then exit 1; fi
