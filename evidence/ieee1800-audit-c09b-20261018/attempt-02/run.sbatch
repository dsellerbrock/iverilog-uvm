#!/usr/bin/env bash
#SBATCH --job-name=a3-ieee-c09b-r2
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c09b-20261018-attempt02/logs/%x-%j.out

set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c09b-20261018-attempt02
INPUT="$RUN/input"
LOGS="$RUN/logs"
BUILD="$RUN/build"
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
IV="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
TIMEOUT="$RUN/run_with_timeout.py"
status=0
mkdir -p "$LOGS" "$BUILD"

{
  echo "host=$(hostname)"
  date -Is
  echo "slurm_job_id=${SLURM_JOB_ID:-none}"
  echo "toolchain_commit=9b5fad2afb4104caa816b257d5bccc40f01b8c66"
  echo "toolchain=$TOOL"
  "$IV" -V 2>&1 | sed -n '1,2p'
  sha256sum "$IV" "$VVP" "$TIMEOUT" "$INPUT"/*.sv
} > "$RUN/results.txt"

positive() {
  local file="$1" edition="$2" base out compile_rc run_rc
  base="${file%.sv}"
  out="$BUILD/$base-$edition.vvp"
  printf '=== %s -g%s ===\n' "$base" "$edition" >> "$RUN/results.txt"
  if python3 "$TIMEOUT" 60 -- "$IV" -g"$edition" -s top -o "$out" "$INPUT/$file" > "$LOGS/$base-$edition.compile.log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
  echo "compile_rc=$compile_rc" >> "$RUN/results.txt"
  cat "$LOGS/$base-$edition.compile.log" >> "$RUN/results.txt"
  if (( compile_rc != 0 )); then status=1; return; fi
  if python3 "$TIMEOUT" 30 -- "$VVP" "$out" > "$LOGS/$base-$edition.run.log" 2>&1; then run_rc=0; else run_rc=$?; fi
  echo "run_rc=$run_rc" >> "$RUN/results.txt"
  cat "$LOGS/$base-$edition.run.log" >> "$RUN/results.txt"
  if (( run_rc != 0 )) || grep -q '^FAIL ' "$LOGS/$base-$edition.run.log"; then status=1; fi
}

for edition in 2017 2023; do
  positive p09_06_1_wait_fork.sv "$edition"
  positive p09_06_1_wait_fork_minimal.sv "$edition"
  positive p09_06_2_disable.sv "$edition"
done

echo "FINAL_STATUS=$status" >> "$RUN/results.txt"
cat "$RUN/results.txt"
exit "$status"
