#!/usr/bin/env bash
#SBATCH --job-name=a3-ieee-c09b
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c09b-20261018-attempt01/logs/%x-%j.out

set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c09b-20261018-attempt01
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
  sha256sum "$IV" "$VVP"
  sha256sum "$TIMEOUT" "$INPUT"/*.sv "$INPUT"/neg/*.sv
} > "$RUN/results.txt"

positive() {
  local file="$1" edition="$2" base out crc=0 rrc=not-run
  base="${file%.sv}"
  out="$BUILD/$base-$edition.vvp"
  printf '=== %s -g%s ===\n' "$base" "$edition" >> "$RUN/results.txt"
  if python3 "$TIMEOUT" 60 -- "$IV" -g"$edition" -s top -o "$out" "$INPUT/$file" > "$LOGS/$base-$edition.compile.log" 2>&1; then crc=0; else crc=$?; fi
  echo "compile_rc=$crc" >> "$RUN/results.txt"
  cat "$LOGS/$base-$edition.compile.log" >> "$RUN/results.txt"
  if (( crc == 0 )); then
    if python3 "$TIMEOUT" 30 -- "$VVP" "$out" > "$LOGS/$base-$edition.run.log" 2>&1; then rrc=0; else rrc=$?; fi
    echo "run_rc=$rrc" >> "$RUN/results.txt"
    cat "$LOGS/$base-$edition.run.log" >> "$RUN/results.txt"
    if (( rrc != 0 )) || grep -q '^FAIL ' "$LOGS/$base-$edition.run.log" \
      || ! grep -q '^DONE fails=0$' "$LOGS/$base-$edition.run.log"; then status=1; fi
  else
    status=1
  fi
}

negative() {
  local file="$1" edition="$2" base rc=0
  base="${file%.sv}"
  printf '=== %s -g%s expected-reject ===\n' "$base" "$edition" >> "$RUN/results.txt"
  if python3 "$TIMEOUT" 60 -- "$IV" -g"$edition" -s top -tnull "$INPUT/neg/$file" > "$LOGS/$base-$edition.compile.log" 2>&1; then rc=0; else rc=$?; fi
  echo "compile_rc=$rc (expected nonzero)" >> "$RUN/results.txt"
  cat "$LOGS/$base-$edition.compile.log" >> "$RUN/results.txt"
  if (( rc == 0 || rc == 124 )); then status=1; fi
}

for edition in 2017 2023; do
  positive p09_06_1_wait_fork.sv "$edition"
  positive p09_06_2_disable.sv "$edition"
  positive p09_06_3_disable_fork.sv "$edition"
  negative n09_06_2_disable_function.sv "$edition"
done

echo "FINAL_STATUS=$status" >> "$RUN/results.txt"
cat "$RUN/results.txt"
exit "$status"
