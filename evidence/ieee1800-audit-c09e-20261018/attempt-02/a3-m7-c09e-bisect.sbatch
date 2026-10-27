#!/usr/bin/env bash
#SBATCH --job-name=a3-m7-c09e-b
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=10
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
for edition in 2017 2023; do
  for rel in p09_04_2_implicit_star.sv p09_04_2_objects.sv p09_04_2_array_size_event.sv; do
    tag="${edition}_$rel"
    tag="${tag%.sv}"
    printf '\n=== -g%s %s ===\n' "$edition" "$rel"
    timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$edition" -B "$TOOL/lib/ivl" -s top -o "$RUN/out/$tag.vvp" "$RUN/inputs/$rel" >"$RUN/logs/$tag.compile.out" 2>"$RUN/logs/$tag.compile.err"
    compile_rc=$?
    printf 'compile_rc=%s\n' "$compile_rc"
    cat "$RUN/logs/$tag.compile.out" "$RUN/logs/$tag.compile.err"
    run_rc=NA
    if [ "$compile_rc" -eq 0 ]; then
      timeout --signal=TERM --kill-after=5s 30s "$VVP" "$RUN/out/$tag.vvp" >"$RUN/logs/$tag.run.out" 2>"$RUN/logs/$tag.run.err"
      run_rc=$?
      printf 'run_rc=%s\n' "$run_rc"
      cat "$RUN/logs/$tag.run.out" "$RUN/logs/$tag.run.err"
      if [ "$run_rc" -ne 0 ] || ! grep -Fq 'DONE fails=0' "$RUN/logs/$tag.run.out"; then status=1; fi
    else
      status=1
    fi
    printf 'RESULT %s compile_rc=%s run_rc=%s\n' "$tag" "$compile_rc" "$run_rc"
  done
done
printf '\nDONE status=%s\n' "$status"
exit "$status"
