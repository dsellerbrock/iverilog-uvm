#!/usr/bin/env bash
#SBATCH --job-name=a3-418-t0t1
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=3G
#SBATCH --time=00:30:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue418-joint-20261017-t0t1-05/logs/%x-%j.out
set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/issue418-joint-20261017-t0t1-05
set +e
/usr/bin/time -v /bin/bash "$RUN_DIR/run-body.sh"
rc=$?
printf 'job_exit=%s\n' "$rc" > "$RUN_DIR/results/job.exit"
exit "$rc"
