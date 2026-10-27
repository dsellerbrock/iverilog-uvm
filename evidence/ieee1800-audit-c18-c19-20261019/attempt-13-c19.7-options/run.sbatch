#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c19-7
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-7-options-20261019/logs/%x-%j.out
set -uo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-7-options-20261019
TOOL=/home/dsell/toolchains/iverilog-a3-main-82023726-679
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
RESULTS="$RUN/results"
mkdir -p "$RESULTS" "$RUN/logs"
cd "$RUN"

{
  date -Is
  hostname
  uname -a
  printf 'RUN=%s\nTOOL=%s\nIVL=%s\nVVP=%s\n' "$RUN" "$TOOL" "$IVL" "$VVP"
  sha256sum "$IVL" "$VVP" "$TOOL/lib/ivl/ivl"
  "$IVL" -B "$TOOL/lib/ivl" -V 2>&1
  "$VVP" -V 2>&1
} > "$RESULTS/environment.txt"
sha256sum input/*.sv input/neg/*.sv > "$RESULTS/input.sha256"
: > "$RESULTS/status.txt"
status=0

timed() {
  local name="$1" rc
  shift
  printf '%q ' "$@" > "$RESULTS/$name.command"
  printf '\n' >> "$RESULTS/$name.command"
  if /usr/bin/time -f 'wall_s=%e peak_rss_kib=%M' -o "$RESULTS/$name.time" \
      timeout -k 5s 60s "$@" > "$RESULTS/$name.log" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  printf '%s\n' "$rc" > "$RESULTS/$name.exit"
  return 0
}

run_positive() {
  local name="$1" edition="$2" source="$3" top="$4" base rc
  base="$RESULTS/$name-$edition"
  timed "$name-$edition-compile" "$IVL" -B "$TOOL/lib/ivl" -g"$edition" \
    -s "$top" "$RUN/input/$source" -o "$base.vvp"
  rc=$(cat "$RESULTS/$name-$edition-compile.exit")
  if [[ "$rc" != 0 ]]; then
    printf 'positive-%s-%s-compile=FAIL(%s)\n' "$name" "$edition" "$rc" >> "$RESULTS/status.txt"
    status=1
    return
  fi
  timed "$name-$edition-run" "$VVP" -n "$base.vvp"
  rc=$(cat "$RESULTS/$name-$edition-run.exit")
  if [[ "$rc" == 0 ]] && grep -Eq '^PASS 19\.7' "$RESULTS/$name-$edition-run.log"; then
    printf 'positive-%s-%s=PASS\n' "$name" "$edition" >> "$RESULTS/status.txt"
  else
    printf 'positive-%s-%s-run=FAIL(%s)\n' "$name" "$edition" "$rc" >> "$RESULTS/status.txt"
    status=1
  fi
}

run_rejection() {
  local name="$1" edition="$2" source="$3" rc log
  log="$RESULTS/$name-$edition"
  timed "$name-$edition-compile" "$IVL" -B "$TOOL/lib/ivl" -g"$edition" \
    -tnull "$RUN/input/$source"
  rc=$(cat "$RESULTS/$name-$edition-compile.exit")
  if [[ "$rc" != 0 && "$rc" != 124 && "$rc" != 137 ]] \
      && ! grep -Eqi 'assert:|assertion|segmentation|Aborted|core dumped' "$RESULTS/$name-$edition-compile.log"; then
    printf 'expected-rejection-%s-%s=PASS(exit=%s)\n' "$name" "$edition" "$rc" >> "$RESULTS/status.txt"
  else
    printf 'expected-rejection-%s-%s=FAIL(exit=%s)\n' "$name" "$edition" "$rc" >> "$RESULTS/status.txt"
    status=1
  fi
}

run_positive common-coverage-options 2017 p19_07_options.sv test
run_positive common-coverage-options 2023 p19_07_options.sv test
run_positive 2023-coverage-options 2023 p19_07_options_2023.sv test_2023
run_rejection 2023-coverage-options 2017 p19_07_options_2023.sv
run_rejection duplicate-option 2017 neg/n19_07_dup_option.sv
run_rejection duplicate-option 2023 neg/n19_07_dup_option.sv
run_rejection invalid-type-option 2017 neg/n19_07_invalid_type_option.sv
run_rejection invalid-type-option 2023 neg/n19_07_invalid_type_option.sv

if [[ "$status" == 0 ]]; then result=PASS; else result=FAIL; fi
printf 'GATE_RESULT=%s\n' "$result" | tee "$RESULTS/RESULT.txt"
exit "$status"
