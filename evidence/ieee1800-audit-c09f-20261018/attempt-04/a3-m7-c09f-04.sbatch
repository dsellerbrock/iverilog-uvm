#!/usr/bin/env bash
#SBATCH --job-name=a3-m7-c09f-04
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c09f-20261018-04/logs/%x-%j.out

set -u
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c09f-20261018-04
BIN=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install/bin
IVERILOG="$BIN/iverilog"
VVP="$BIN/vvp"

echo "host=$(hostname)"
echo "job_id=${SLURM_JOB_ID:-unknown}"
echo "toolchain=$BIN"
sha256sum "$IVERILOG" "$VVP"

for edition in 2017 2023; do
    label="${edition}_p09_04_5_repeat_z"
    image="$RUN/out/$label.vvp"
    timeout --signal=TERM --kill-after=5s 30s "$IVERILOG" "-g$edition" -s top -o "$image" "$RUN/inputs/p09_04_5_repeat_z.sv" >"$RUN/logs/$label.compile.out" 2>"$RUN/logs/$label.compile.err"
    compile_rc=$?
    echo "=== $label compile_rc=$compile_rc ==="
    cat "$RUN/logs/$label.compile.out" "$RUN/logs/$label.compile.err"
    if [ "$compile_rc" -eq 0 ]; then
        timeout --signal=TERM --kill-after=5s 30s "$VVP" "$image" >"$RUN/logs/$label.run.out" 2>"$RUN/logs/$label.run.err"
        run_rc=$?
        echo "=== $label run_rc=$run_rc ==="
        cat "$RUN/logs/$label.run.out" "$RUN/logs/$label.run.err"
    fi
done
echo HARNESS_STATUS=0
