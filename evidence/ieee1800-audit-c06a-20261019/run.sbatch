#!/usr/bin/env bash
#SBATCH --job-name=a3-c06-16
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=128M
#SBATCH --time=00:25:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog/a3/ieee1800-c06a-20261019-01/logs/slurm-%j.out
set -uo pipefail
cd /home/dsell/slurm-runs/iverilog/a3/ieee1800-c06a-20261019-01
tar -xzf probe-input.tar.gz
bash run-probes.sh | tee logs/terminal-output.txt
