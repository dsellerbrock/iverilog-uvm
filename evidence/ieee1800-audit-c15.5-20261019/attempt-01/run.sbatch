#!/usr/bin/env bash
#SBATCH --job-name=a3-c15-5
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:30:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15.5-20261019-1/logs/%x-%j.out

set -uo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15.5-20261019-1
MAIN=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
STAGE=/home/dsell/slurm-runs/iverilog-uvm/A3/t2-batch-20261019-4-r2/source/local-install/bin
SUMMARY="$RUN/results/summary.tsv"

mkdir -p "$RUN/results/output"
printf 'toolchain\tedition\tprobe\tcompile_rc\trun_rc\n' > "$SUMMARY"
{
  echo "host=$(hostname)"
  echo "main_commit=cae035642e056644274a01e98d4422ce286685b4"
  echo "stage_commit=627dbe15cd33566050a1e737e3c9b89c76a0c8db"
  sha256sum "$MAIN/iverilog" "$MAIN/vvp" "$STAGE/iverilog" "$STAGE/vvp"
} > "$RUN/results/metadata.txt"

probes=(
  p15_05_basic_event
  p15_05_persistent_triggered
  p15_05_wait_order
  p15_05_event_handles
  p15_05_nonblocking_trigger
  p15_05_event_reclaim
)

for toolchain in main stage; do
  if [[ "$toolchain" == main ]]; then BIN="$MAIN"; else BIN="$STAGE"; fi
  for edition in 2017 2023; do
    for probe in "${probes[@]}"; do
      stem="$RUN/results/output/${toolchain}-${edition}-${probe}"
      set +e
      python3 "$RUN/input/run_with_timeout.py" 120 -- "$BIN/iverilog" "-g$edition" -s test -o "$stem.vvp" "$RUN/input/$probe.sv" > "$stem.compile.log" 2>&1
      compile_rc=$?
      run_rc=SKIPPED
      if [[ $compile_rc -eq 0 ]]; then
        python3 "$RUN/input/run_with_timeout.py" 120 -- "$BIN/vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1
        run_rc=$?
      fi
      set -e
      printf '%s\t%s\t%s\t%s\t%s\n' "$toolchain" "$edition" "$probe" "$compile_rc" "$run_rc" | tee -a "$SUMMARY"
    done
  done
done

exit 0
