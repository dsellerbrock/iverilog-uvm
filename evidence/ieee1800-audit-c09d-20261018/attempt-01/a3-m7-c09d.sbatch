#!/usr/bin/env bash
#SBATCH --job-name=a3-m7-c09d
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=5
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
set -u
RUN="$PWD"
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
status=0
printf 'host=%s\nstart=%s\njob_id=%s\n' "$(hostname)" "$(date --iso-8601=seconds)" "${SLURM_JOB_ID:-none}"
printf 'toolchain=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66\n'
sha256sum "$IVL" "$VVP"
for edition in 2017 2023; do
  printf '\n=== -g%s ===\n' "$edition"
  timeout --signal=TERM --kill-after=5s 30s "$IVL" -g"$edition" -B "$TOOL/lib/ivl" -s top -o "$RUN/out/$edition.vvp" "$RUN/inputs/p09_07_resume_semantics.sv" >"$RUN/logs/$edition.compile.out" 2>"$RUN/logs/$edition.compile.err"
  compile_rc=$?
  printf 'compile_rc=%s\n' "$compile_rc"
  cat "$RUN/logs/$edition.compile.out" "$RUN/logs/$edition.compile.err"
  run_rc=NA
  if [ "$compile_rc" -eq 0 ]; then
    timeout --signal=TERM --kill-after=5s 30s "$VVP" "$RUN/out/$edition.vvp" >"$RUN/logs/$edition.run.out" 2>"$RUN/logs/$edition.run.err"
    run_rc=$?
    printf 'run_rc=%s\n' "$run_rc"
    cat "$RUN/logs/$edition.run.out" "$RUN/logs/$edition.run.err"
    if [ "$run_rc" -ne 0 ] || ! grep -Fq 'DONE fails=0' "$RUN/logs/$edition.run.out"; then status=1; fi
  else
    status=1
  fi
  printf 'RESULT edition=%s compile_rc=%s run_rc=%s\n' "$edition" "$compile_rc" "$run_rc"
done
printf '\nDONE status=%s\n' "$status"
exit "$status"
