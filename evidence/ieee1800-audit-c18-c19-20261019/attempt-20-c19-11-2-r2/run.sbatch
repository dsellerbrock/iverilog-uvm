#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-audit-c19-11-2-r2
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-11-2-r2-20261019
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-11-2-r2-20261019/logs/%x-%j.out
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-11-2-r2-20261019
TOOL=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
IVL=$TOOL/iverilog
VVP=$TOOL/vvp
mkdir -p "$RUN/logs" "$RUN/results"
status=0
finish() {
  rc=$?
  trap - EXIT
  printf 'script_exit=%s\nfinished=%s\n' "$rc" "$(date -Is)" > "$RUN/results/result.txt"
  exit "$rc"
}
trap finish EXIT
{
  printf 'job_id=%s\nhost=%s\nstarted=%s\nmain_commit=cae035642e056644274a01e98d4422ce286685b4\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)"
  printf 'iverilog=%s\nvvp=%s\n' "$($IVL -V 2>&1 | head -1)" "$($VVP -V 2>&1 | head -1)"
  sha256sum "$IVL" "$VVP"
  sha256sum "$RUN/input"/*.sv
} > "$RUN/results/manifest.txt"
for edition in 2017 2023; do
  set +e
  timeout --signal=TERM --kill-after=5s 90s "$IVL" -g"$edition" -s test \
    -o "$RUN/results/p19_11_2_$edition.vvp" \
    "$RUN/input/p19_11_2_cross_computation.sv" \
    > "$RUN/logs/p19_11_2_$edition.compile.log" 2>&1
  compile_rc=$?
  set -e
  printf '%s\n' "$compile_rc" > "$RUN/results/p19_11_2_$edition.compile.exit"
  if [ "$compile_rc" -ne 0 ]; then status=1; continue; fi
  set +e
  timeout --signal=TERM --kill-after=5s 90s "$VVP" \
    "$RUN/results/p19_11_2_$edition.vvp" \
    > "$RUN/logs/p19_11_2_$edition.run.log" 2>&1
  run_rc=$?
  set -e
  printf '%s\n' "$run_rc" > "$RUN/results/p19_11_2_$edition.run.exit"
  if [ "$run_rc" -ne 0 ] || [ ! -s "$RUN/logs/p19_11_2_$edition.run.log" ]; then status=1; fi
  if ! grep -q 'PASS cross computation clause 19.11.2' "$RUN/logs/p19_11_2_$edition.run.log"; then status=1; fi
done
for edition in 2017 2023; do
  set +e
  timeout --signal=TERM --kill-after=5s 90s "$IVL" -g"$edition" -tnull -s test \
    "$RUN/input/n19_11_2_two_arg_cross.sv" \
    > "$RUN/logs/n19_11_2_two_arg_cross_$edition.compile.log" 2>&1
  rc=$?
  set -e
  printf '%s\n' "$rc" > "$RUN/results/n19_11_2_two_arg_cross_$edition.compile.exit"
done
printf 'audit_probe_script_status=%s\n' "$status" > "$RUN/results/probe-status.txt"
exit "$status"
