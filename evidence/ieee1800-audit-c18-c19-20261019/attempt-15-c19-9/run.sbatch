#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c19-9
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-9-20261019/logs/%x-%j.out
set -uo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-9-20261019
TOOL=/home/dsell/toolchains/iverilog-a3-main-82023726-679
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
RESULTS="$RUN/results"
mkdir -p "$RESULTS" "$RUN/logs"
cd "$RUN"

sha256sum input/c19.9-probes.tar.gz > "$RESULTS/input-archive.sha256"
tar -xzf input/c19.9-probes.tar.gz -C input
sha256sum input/*.sv input/neg/*.sv > "$RESULTS/input.sha256"
{
  date -Is
  hostname
  uname -a
  printf 'RUN=%s\nTOOL=%s\nIVL=%s\nVVP=%s\n' "$RUN" "$TOOL" "$IVL" "$VVP"
  sha256sum "$IVL" "$VVP" "$TOOL/lib/ivl/ivl"
  "$IVL" -B "$TOOL/lib/ivl" -V 2>&1
  "$VVP" -V 2>&1
} > "$RESULTS/environment.txt"
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
  local edition="$1" base rc
  base="$RESULTS/system-tasks-$edition"
  timed "system-tasks-$edition-compile" "$IVL" -B "$TOOL/lib/ivl" -g"$edition" \
    -s test "$RUN/input/p19_09_systasks.sv" -o "$base.vvp"
  rc=$(cat "$RESULTS/system-tasks-$edition-compile.exit")
  if [[ "$rc" != 0 ]]; then
    printf 'positive-%s-compile=FAIL(%s)\n' "$edition" "$rc" >> "$RESULTS/status.txt"
    status=1
    return
  fi
  timed "system-tasks-$edition-run" "$VVP" -n "$base.vvp"
  rc=$(cat "$RESULTS/system-tasks-$edition-run.exit")
  if [[ "$rc" == 0 ]] && grep -Fq 'PASS 19.9 coverage system tasks' "$RESULTS/system-tasks-$edition-run.log"; then
    printf 'positive-%s=PASS\n' "$edition" >> "$RESULTS/status.txt"
  else
    printf 'positive-%s-run=FAIL(%s)\n' "$edition" "$rc" >> "$RESULTS/status.txt"
    status=1
  fi
}

run_rejection() {
  local edition="$1" rc log
  log="$RESULTS/nonstring-filename-$edition"
  timed "nonstring-filename-$edition-compile" "$IVL" -B "$TOOL/lib/ivl" -g"$edition" \
    -tnull "$RUN/input/neg/n19_09_set_db_name_nonstring.sv"
  rc=$(cat "$RESULTS/nonstring-filename-$edition-compile.exit")
  if [[ "$rc" != 0 && "$rc" != 124 && "$rc" != 137 ]] \
      && ! grep -Eqi 'assert:|assertion|segmentation|Aborted|core dumped' "$RESULTS/nonstring-filename-$edition-compile.log"; then
    printf 'expected-rejection-%s=PASS(exit=%s)\n' "$edition" "$rc" >> "$RESULTS/status.txt"
  else
    printf 'expected-rejection-%s=FAIL(exit=%s)\n' "$edition" "$rc" >> "$RESULTS/status.txt"
    status=1
  fi
}

run_positive 2017
run_positive 2023
run_rejection 2017
run_rejection 2023

if [[ "$status" == 0 ]]; then result=PASS; else result=FAIL; fi
printf 'GATE_RESULT=%s\n' "$result" | tee "$RESULTS/RESULT.txt"
exit "$status"
