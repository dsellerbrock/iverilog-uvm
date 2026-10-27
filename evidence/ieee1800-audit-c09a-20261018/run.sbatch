#!/usr/bin/env bash
#SBATCH --job-name=a3-ieee-c09a
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c09a-20261018-attempt03/logs/%x-%j.out

set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c09a-20261018-attempt03
INPUT="$RUN/input"
LOGS="$RUN/logs"
BUILD="$RUN/build"
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
IV="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
TIMEOUT=/usr/bin/timeout
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
  sha256sum "$INPUT"/*.sv "$INPUT"/neg/*.sv
} > "$RUN/results.txt"

positive() {
  local file="$1" edition="$2" base out crc=0 rrc=not-run
  base="${file%.sv}"
  out="$BUILD/$base-$edition.vvp"
  printf '=== %s -g%s ===\n' "$base" "$edition" >> "$RUN/results.txt"
  if "$TIMEOUT" -k 2s 60s "$IV" -g"$edition" -s top -o "$out" "$INPUT/$file" > "$LOGS/$base-$edition.compile.log" 2>&1; then crc=0; else crc=$?; fi
  echo "compile_rc=$crc" >> "$RUN/results.txt"
  cat "$LOGS/$base-$edition.compile.log" >> "$RUN/results.txt"
  if (( crc == 0 )); then
    if "$TIMEOUT" -k 2s 30s "$VVP" "$out" > "$LOGS/$base-$edition.run.log" 2>&1; then rrc=0; else rrc=$?; fi
    echo "run_rc=$rrc" >> "$RUN/results.txt"
    cat "$LOGS/$base-$edition.run.log" >> "$RUN/results.txt"
    if (( rrc != 0 )) || grep -q '^FAIL ' "$LOGS/$base-$edition.run.log"; then status=1; fi
    if [[ "$base" == p09_03_blocks ]]; then
      grep -q '^DONE fails=0$' "$LOGS/$base-$edition.run.log" || status=1
      if [[ "$edition" == 2023 ]]; then grep -q '^INFO 9.3.2.m_seen=4 ' "$LOGS/$base-$edition.run.log" || status=1; fi
    else
      grep -q '^PASS ' "$LOGS/$base-$edition.run.log" || status=1
    fi
  else
    status=1
  fi
}

negative() {
  local file="$1" edition="$2" base input rc=0
  base="${file%.sv}"
  if [[ "$file" == p09_03_2_ref_static_fork_2023.sv ]]; then
    input="$INPUT/$file"
  else
    input="$INPUT/neg/$file"
  fi
  printf '=== %s -g%s expected-reject ===\n' "$base" "$edition" >> "$RUN/results.txt"
  if "$TIMEOUT" -k 2s 60s "$IV" -g"$edition" -s top -tnull "$input" > "$LOGS/$base-$edition.compile.log" 2>&1; then rc=0; else rc=$?; fi
  echo "compile_rc=$rc (expected nonzero)" >> "$RUN/results.txt"
  cat "$LOGS/$base-$edition.compile.log" >> "$RUN/results.txt"
  if (( rc == 0 || rc == 124 )) || grep -qE 'No such file or directory|Preprocessor failed' "$LOGS/$base-$edition.compile.log"; then status=1; fi
}

for edition in 2017 2023; do
  positive p09_03_blocks.sv "$edition"
  positive p09_03_2_ref_init_legal.sv "$edition"
  if [[ "$edition" == 2023 ]]; then
    positive p09_03_2_ref_static_fork_2023.sv "$edition"
  else
    negative p09_03_2_ref_static_fork_2023.sv "$edition"
  fi
  for file in n09_03_2_return_in_fork.sv n09_03_2_ref_arg_in_join_none.sv n09_03_2_ref_arg_in_join_any.sv n09_03_4_end_name_mismatch.sv n09_03_4_join_name_mismatch.sv; do
    negative "$file" "$edition"
  done
done

echo "FINAL_STATUS=$status" >> "$RUN/results.txt"
cat "$RUN/results.txt"
exit "$status"
