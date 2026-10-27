#!/usr/bin/env bash
#SBATCH --job-name=a3-m7-c09c
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=10
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
set -uo pipefail
RUN="$PWD"
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
export PATH="$TOOL/bin:$PATH"
printf 'host=%s\nstart=%s\njob_id=%s\n' "$(hostname)" "$(date --iso-8601=seconds)" "${SLURM_JOB_ID:-none}"
printf 'toolchain=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66\n'
sha256sum "$IVL" "$VVP"
probe() {
  local edition="$1" rel="$2" stem tag out compile_rc run_rc
  stem="${rel##*/}"
  stem="${stem%.sv}"
  tag="${edition}_${stem}"
  out="$RUN/out/$tag.vvp"
  printf '\n=== %s %s ===\n' "$edition" "$rel"
  timeout --signal=TERM --kill-after=5s 30s "$IVL" -g"$edition" -B "$TOOL/lib/ivl" -o "$out" "$RUN/inputs/$rel" >"$RUN/logs/$tag.compile.out" 2>"$RUN/logs/$tag.compile.err"
  compile_rc=$?
  printf 'compile_rc=%s\n' "$compile_rc"
  cat "$RUN/logs/$tag.compile.out" "$RUN/logs/$tag.compile.err"
  run_rc=NA
  if [ "$compile_rc" -eq 0 ]; then
    timeout --signal=TERM --kill-after=5s 30s "$VVP" "$out" >"$RUN/logs/$tag.run.out" 2>"$RUN/logs/$tag.run.err"
    run_rc=$?
    printf 'run_rc=%s\n' "$run_rc"
    cat "$RUN/logs/$tag.run.out" "$RUN/logs/$tag.run.err"
  fi
  printf 'RESULT %s compile_rc=%s run_rc=%s\n' "$tag" "$compile_rc" "$run_rc"
}
for edition in 2017 2023; do
  probe "$edition" p09_07_process.sv
  probe "$edition" neg/n09_07_process_extend.sv
  probe "$edition" neg/p09_07_new_process.sv
  probe "$edition" neg/p09_07_await_self.sv
  probe "$edition" neg/p09_07_suspend_self_in_function.sv
done
printf '\nDONE all probes executed\n'
