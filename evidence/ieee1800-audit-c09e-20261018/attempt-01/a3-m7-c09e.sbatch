#!/usr/bin/env bash
#SBATCH --job-name=a3-m7-c09e
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=25
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
set -u
RUN="$PWD"
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
status=0
printf 'host=%s\nstart=%s\njob_id=%s\n' "$(hostname)" "$(date --iso-8601=seconds)" "${SLURM_JOB_ID:-none}"
printf 'toolchain=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install\n'
sha256sum "$IVL" "$VVP"

positive() {
  local edition="$1" rel="$2" stem tag compile_rc run_rc
  stem="${rel##*/}"
  stem="${stem%.sv}"
  tag="${edition}_${stem}"
  printf '\n=== %s %s ===\n' "$edition" "$rel"
  timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$edition" -B "$TOOL/lib/ivl" -s top -o "$RUN/out/$tag.vvp" "$RUN/inputs/$rel" >"$RUN/logs/$tag.compile.out" 2>"$RUN/logs/$tag.compile.err"
  compile_rc=$?
  printf 'compile_rc=%s\n' "$compile_rc"
  cat "$RUN/logs/$tag.compile.out" "$RUN/logs/$tag.compile.err"
  if [ "$compile_rc" -ne 0 ]; then status=1; return; fi
  timeout --signal=TERM --kill-after=5s 30s "$VVP" "$RUN/out/$tag.vvp" >"$RUN/logs/$tag.run.out" 2>"$RUN/logs/$tag.run.err"
  run_rc=$?
  printf 'run_rc=%s\n' "$run_rc"
  cat "$RUN/logs/$tag.run.out" "$RUN/logs/$tag.run.err"
  if [ "$run_rc" -ne 0 ] || ! grep -Fq 'DONE fails=0' "$RUN/logs/$tag.run.out"; then status=1; fi
  printf 'RESULT %s compile_rc=%s run_rc=%s\n' "$tag" "$compile_rc" "$run_rc"
}

negative() {
  local edition="$1" rel="$2" tag compile_rc run_rc
  tag="${edition}_n09_04_2_nonsingular_event"
  printf '\n=== %s %s ===\n' "$edition" "$rel"
  timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$edition" -B "$TOOL/lib/ivl" -s top -o "$RUN/out/$tag.vvp" "$RUN/inputs/$rel" >"$RUN/logs/$tag.compile.out" 2>"$RUN/logs/$tag.compile.err"
  compile_rc=$?
  printf 'compile_rc=%s\n' "$compile_rc"
  cat "$RUN/logs/$tag.compile.out" "$RUN/logs/$tag.compile.err"
  if [ "$compile_rc" -eq 0 ]; then
    timeout --signal=TERM --kill-after=5s 30s "$VVP" "$RUN/out/$tag.vvp" >"$RUN/logs/$tag.run.out" 2>"$RUN/logs/$tag.run.err"
    run_rc=$?
    printf 'run_rc=%s\n' "$run_rc"
    cat "$RUN/logs/$tag.run.out" "$RUN/logs/$tag.run.err"
    if grep -Fq 'NEG_NOT_REJECTED' "$RUN/logs/$tag.run.out"; then status=1; fi
    printf 'RESULT %s compile_rc=%s run_rc=%s\n' "$tag" "$compile_rc" "$run_rc"
  else
    printf 'RESULT %s compile_rc=%s run_rc=NA (rejected; diagnostic retained for review)\n' "$tag" "$compile_rc"
  fi
}

for edition in 2017 2023; do
  positive "$edition" p09_04_1_delay.sv
  positive "$edition" p09_04_2_edges.sv
  positive "$edition" p09_04_2_or_iff.sv
  positive "$edition" p09_04_2_implicit_star.sv
  positive "$edition" p09_04_2_objects.sv
  negative "$edition" neg/n09_04_2_nonsingular_event.sv
done
printf '\nDONE status=%s\n' "$status"
exit "$status"
