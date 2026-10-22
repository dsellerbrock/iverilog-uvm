#!/usr/bin/env bash
#SBATCH --job-name=a3-c13a-02
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13a-20261017-02/logs/%x-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13a-20261017-02
SRC="$RUN/inputs/c13"
IVL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install/bin/vvp
mkdir -p "$RUN/build" "$RUN/logs"
status=0
{
  echo "host=$(hostname)"
  date -Is
  echo "toolchain=$IVL"
  sha256sum "$IVL" "$VVP"
  "$IVL" -V 2>&1 | head -n 5
  "$VVP" -V 2>&1 | head -n 5
  echo "Per-test timeout: compile 30s; run 10s; SIGTERM then SIGKILL after 2s."
} > "$RUN/logs/results.txt"

compile_run() {
  local name="$1" edition="$2" source="$3" expected="$4" log="$RUN/logs/$1-$2.log" out="$RUN/build/$1-$2.vvp" rc
  printf '\n=== %s -g%s ===\n' "$name" "$edition" >> "$RUN/logs/results.txt"
  printf 'compile: timeout -k 2s 30s %s -g%s -o %s %s\n' "$IVL" "$edition" "$out" "$source" >> "$RUN/logs/results.txt"
  if timeout -k 2s 30s "$IVL" -g"$edition" -o "$out" "$source" > "$log" 2>&1; then rc=0; else rc=$?; fi
  cat "$log" >> "$RUN/logs/results.txt"
  if [[ $rc -ne 0 ]]; then
    echo "FAIL compile rc=$rc" >> "$RUN/logs/results.txt"
    status=1
    return
  fi
  printf 'run: timeout -k 2s 10s %s %s\n' "$VVP" "$out" >> "$RUN/logs/results.txt"
  if timeout -k 2s 10s "$VVP" "$out" > "$log.run" 2>&1; then rc=0; else rc=$?; fi
  cat "$log.run" >> "$RUN/logs/results.txt"
  if [[ $rc -ne 0 ]] || grep -q '^FAIL' "$log.run" || ! grep -q "$expected" "$log.run"; then
    echo "FAIL run rc=$rc expected=$expected" >> "$RUN/logs/results.txt"
    status=1
  else
    echo "PASS run" >> "$RUN/logs/results.txt"
  fi
}

compile_reject() {
  local name="$1" edition="$2" source="$3" log="$RUN/logs/$1-$2.log" rc
  printf '\n=== expect compile rejection: %s -g%s ===\n' "$name" "$edition" >> "$RUN/logs/results.txt"
  printf 'compile: timeout -k 2s 30s %s -g%s -tnull %s\n' "$IVL" "$edition" "$source" >> "$RUN/logs/results.txt"
  if timeout -k 2s 30s "$IVL" -g"$edition" -tnull "$source" > "$log" 2>&1; then
    cat "$log" >> "$RUN/logs/results.txt"
    echo "FAIL unexpectedly compiled" >> "$RUN/logs/results.txt"
    status=1
  else
    rc=$?
    cat "$log" >> "$RUN/logs/results.txt"
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then
      echo "FAIL timeout rc=$rc" >> "$RUN/logs/results.txt"
      status=1
    else
      echo "PASS rejected rc=$rc" >> "$RUN/logs/results.txt"
    fi
  fi
}

for edition in 2017 2023; do
  compile_run p13_05_args_core "$edition" "$SRC/p13_05_args_core.sv" 'DONE fails=0'
  compile_run p13_05_3_output_default "$edition" "$SRC/p13_05_3_output_default.sv" '^PASS 13.5.3.output_default_binds'
  compile_run p13_05_3_inout_default "$edition" "$SRC/p13_05_3_inout_default.sv" '^PASS 13.5.3.inout_default'
  compile_reject n13_05_2_ref_in_implicit_static_sub "$edition" "$SRC/neg/n13_05_2_ref_in_implicit_static_sub.sv"
  compile_reject n13_05_3_default_unresolved_input "$edition" "$SRC/neg/n13_05_3_default_unresolved_input.sv"
done
printf '\nFINAL_STATUS=%d\n' "$status" >> "$RUN/logs/results.txt"
exit "$status"
