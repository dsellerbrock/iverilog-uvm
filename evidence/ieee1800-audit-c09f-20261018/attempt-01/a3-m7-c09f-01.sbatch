#!/usr/bin/env bash
#SBATCH --job-name=a3-m7-c09f-01
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=30
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
set -u
RUN="$PWD"
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
runner_status=0
printf 'host=%s\nstart=%s\njob_id=%s\n' "$(hostname)" "$(date --iso-8601=seconds)" "${SLURM_JOB_ID:-none}"
printf 'toolchain=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install\n'
sha256sum "$IVL" "$VVP"

for edition in 2017 2023; do
  for rel in \
    p09_04_3_wait.sv \
    p09_04_3_wait_methods.sv \
    p09_04_4_sequence_triggered.sv \
    p09_04_2_4_sequence_event.sv; do
    tag="${edition}_${rel%.sv}"
    printf '\n=== -g%s %s ===\n' "$edition" "$rel"
    timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$edition" -B "$TOOL/lib/ivl" -s top \
      -o "$RUN/out/$tag.vvp" "$RUN/inputs/$rel" >"$RUN/logs/$tag.compile.out" 2>"$RUN/logs/$tag.compile.err"
    compile_rc=$?
    printf 'compile_rc=%s\n' "$compile_rc"
    cat "$RUN/logs/$tag.compile.out" "$RUN/logs/$tag.compile.err"
    if [ "$compile_rc" -eq 0 ]; then
      timeout --signal=TERM --kill-after=5s 30s "$VVP" "$RUN/out/$tag.vvp" >"$RUN/logs/$tag.run.out" 2>"$RUN/logs/$tag.run.err"
      run_rc=$?
      printf 'run_rc=%s\n' "$run_rc"
      cat "$RUN/logs/$tag.run.out" "$RUN/logs/$tag.run.err"
      if [ "$run_rc" -eq 124 ] || [ "$run_rc" -eq 137 ]; then runner_status=1; fi
      if grep -Fq 'DONE fails=0' "$RUN/logs/$tag.run.out"; then
        printf 'PROBE_STATUS %s assertions-passed\n' "$tag"
      elif grep -Fq 'DONE fails=' "$RUN/logs/$tag.run.out"; then
        printf 'PROBE_STATUS %s assertions-failed\n' "$tag"
      else
        printf 'PROBE_STATUS %s no-complete-result\n' "$tag"
      fi
    else
      printf 'PROBE_STATUS %s compile-failed\n' "$tag"
      if [ "$compile_rc" -eq 124 ] || [ "$compile_rc" -eq 137 ]; then runner_status=1; fi
    fi
  done

  rel=neg/n09_04_2_4_automatic_seq_arg.sv
  tag="${edition}_n09_04_2_4_automatic_seq_arg"
  printf '\n=== -g%s expected compile rejection %s ===\n' "$edition" "$rel"
  timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$edition" -B "$TOOL/lib/ivl" -s top \
    -o "$RUN/out/$tag.vvp" "$RUN/inputs/$rel" >"$RUN/logs/$tag.compile.out" 2>"$RUN/logs/$tag.compile.err"
  compile_rc=$?
  printf 'compile_rc=%s\n' "$compile_rc"
  cat "$RUN/logs/$tag.compile.out" "$RUN/logs/$tag.compile.err"
  if [ "$compile_rc" -eq 0 ]; then
    printf 'PROBE_STATUS %s unexpectedly-accepted\n' "$tag"
  elif [ "$compile_rc" -eq 124 ] || [ "$compile_rc" -eq 137 ]; then
    printf 'PROBE_STATUS %s compiler-timeout\n' "$tag"
    runner_status=1
  else
    printf 'PROBE_STATUS %s compile-rejected\n' "$tag"
  fi
done
printf '\nRUNNER_STATUS=%s\n' "$runner_status"
exit "$runner_status"
