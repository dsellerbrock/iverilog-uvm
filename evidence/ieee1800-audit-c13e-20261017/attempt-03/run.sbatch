#!/usr/bin/env bash
#SBATCH --job-name=a3-c13e-9b5
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13e-20261017-attempt03/logs/a3-c13e-%j.out

set -euo pipefail
bash /home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13e-20261017-attempt03/run.sh
