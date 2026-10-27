#!/usr/bin/env bash
#SBATCH --job-name=a3-c13c-b
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13c-20261017/attempt-02/logs/%x-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13c-20261017/attempt-02
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
  if [[ "$mode" == required ]]; then
    if [[ $rc -ne 0 ]] || grep -q '^FAIL' "$log.run"; then
      status=1
    elif [[ "$name" == p13_04_1_fn_scope_hier ]] \
      && ! grep -Fq 'PASS 13.4.1.fn_name_hier_scope (4)' "$log.run"; then
      status=1
    elif [[ "$name" == p13_04_1_implicit_var_2023 ]] \
      && { ! grep -Fq 'PASS 13.4.1.F().member_implicit (1)' "$log.run" \
        || ! grep -Fq 'PASS 13.4.1.implicit_var_index' "$log.run"; }; then
      status=1
    fi
  else
    echo "2017 result informational; 2023 implicit-variable rule is not required here." >> "$RUN/logs/results.txt"
  fi
}

for edition in 2017 2023; do
  compile_run p13_04_1_fn_scope_hier "$edition" \
    "$SRC/p13_04_1_fn_scope_hier.sv" required
  if [[ "$edition" == 2023 ]]; then mode=required; else mode=informational; fi
  compile_run p13_04_1_implicit_var_2023 "$edition" \
    "$SRC/p13_04_1_implicit_var_2023.sv" "$mode"
done
printf '\nFINAL_STATUS=%d\n' "$status" >> "$RUN/logs/results.txt"
exit "$status"
