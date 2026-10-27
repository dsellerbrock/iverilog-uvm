#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-9-4-context
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-9.4-20261019-17
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-9.4-20261019-17/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-9.4-20261019-17
TOOLCHAIN=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
RESULTS="$RUN_DIR/results"
IVERILOG="$TOOLCHAIN/bin/iverilog"
VVP="$TOOLCHAIN/bin/vvp"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\ntoolchain_source=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/input"/*.sv "$RUN_DIR/input"/neg/*.sv | tee "$RESULTS/input.sha256"
sha256sum "$IVERILOG" "$VVP" | tee "$RESULTS/compiler.sha256"
for edition in 2017 2023; do
  for source in p16_09_04_future_gclk.sv p16_09_04_past_gclk_procedural.sv n16_09_04_no_global_clock.sv n16_09_04_future_gclk_procedural.sv n16_09_04_nested_future_gclk.sv; do
    case "$source" in
      n*) src="$RUN_DIR/input/neg/$source" ;;
      *) src="$RUN_DIR/input/$source" ;;
    esac
    stem="${source%.sv}-$edition"
    set +e
    timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$TOOLCHAIN/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/$stem.vvp" "$src" > "$RESULTS/$stem.compile.log" 2>&1
    compile_rc=$?
    set -e
    printf 'compile_exit=%s\n' "$compile_rc" | tee -a "$RESULTS/$stem.compile.log"
    if test "$compile_rc" -eq 0; then
      set +e
      timeout --signal=TERM --kill-after=5s 120s "$VVP" -n "$RESULTS/$stem.vvp" > "$RESULTS/$stem.run.log" 2>&1
      run_rc=$?
      set -e
      printf 'run_exit=%s\n' "$run_rc" | tee -a "$RESULTS/$stem.run.log"
    fi
    printf '\n=== %s ===\n' "$stem"
    cat "$RESULTS/$stem.compile.log"
    test ! -f "$RESULTS/$stem.run.log" || cat "$RESULTS/$stem.run.log"
  done
done
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/metadata.txt"
