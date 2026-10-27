#!/usr/bin/env bash
#SBATCH --job-name=a3-c13d
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13d-20261017/logs/%x-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13d-20261017
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
  echo "Per-test timeout: compile 60s; run 30s; SIGTERM then SIGKILL after 2s."
} > "$RUN/logs/results.txt"

compile_run() {
  local name="$1" edition="$2" source="$3" mode="$4"
  local log="$RUN/logs/$name-$edition.log" out="$RUN/build/$name-$edition.vvp" rc
  printf '\n=== %s -g%s ===\n' "$name" "$edition" >> "$RUN/logs/results.txt"
  if timeout -k 2s 60s "$IVL" -g"$edition" -o "$out" "$source" > "$log" 2>&1; then rc=0; else rc=$?; fi
  cat "$log" >> "$RUN/logs/results.txt"
  if [[ $rc -ne 0 ]]; then
    echo "compile_rc=$rc" >> "$RUN/logs/results.txt"
    if [[ "$mode" == required ]]; then status=1; fi
    return
  fi
  if timeout -k 2s 30s "$VVP" "$out" > "$log.run" 2>&1; then rc=0; else rc=$?; fi
  echo "run_rc=$rc" >> "$RUN/logs/results.txt"
  cat "$log.run" >> "$RUN/logs/results.txt"
  if [[ "$mode" == tasks ]]; then
    if [[ $rc -ne 0 ]] || grep -q '^FAIL' "$log.run" || ! grep -q '^DONE fails=0$' "$log.run"; then status=1; fi
  elif [[ "$mode" == constfn2023 ]]; then
    if [[ $rc -ne 0 ]] || grep -q '^FAIL' "$log.run" \
      || ! grep -Fq 'PASS 13.4.3 Q=4 R=5' "$log.run" \
      || grep -q 'SYS_TASK_RAN' "$log.run"; then status=1; fi
  else
    echo "2017 constant-function result informational for 2023 built-in-method rule." >> "$RUN/logs/results.txt"
  fi
}

compile_reject() {
  local name="$1" edition="$2" source="$3" log="$RUN/logs/$1-$2.log" rc
  printf '\n=== expect compile rejection: %s -g%s ===\n' "$name" "$edition" >> "$RUN/logs/results.txt"
  if timeout -k 2s 60s "$IVL" -g"$edition" -tnull "$source" > "$log" 2>&1; then
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
      echo "rejected_rc=$rc; inspect diagnostic for direct relevance" >> "$RUN/logs/results.txt"
    fi
  fi
}

for edition in 2017 2023; do
  compile_run p13_03_tasks "$edition" "$SRC/p13_03_tasks.sv" tasks
  if [[ "$edition" == 2023 ]]; then mode=constfn2023; else mode=informational; fi
  compile_run p13_04_3_constfn "$edition" "$SRC/p13_04_3_constfn.sv" "$mode"
  for name in \
    n13_03_1_auto_hier_ref \
    n13_03_2_auto_nba \
    n13_03_2_auto_force \
    n13_03_2_auto_monitor \
    n13_04_3_fork \
    n13_04_3_hier_ref \
    n13_04_3_nonlocal_id \
    n13_04_3_nonconst_sysfn \
    n13_04_3_nba; do
    compile_reject "$name" "$edition" "$SRC/neg/$name.sv"
  done
done
printf '\nFINAL_STATUS=%d\n' "$status" >> "$RUN/logs/results.txt"
exit "$status"
