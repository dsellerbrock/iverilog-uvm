#!/usr/bin/env bash
set -euo pipefail
EVID=evidence/ieee1800-audit-c07a-20261020/attempt-03-pop-default
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-audit-c07a-20261020-03
ssh -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=4 DAN-DESKTOP "mkdir -p '$RUN/input' '$RUN/logs'"
scp -q -o ServerAliveInterval=30 -o ServerAliveCountMax=4 "$EVID/run.sbatch" "$EVID/input.tar.gz" DAN-DESKTOP:"$RUN/"
ssh -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=4 DAN-DESKTOP "cd '$RUN' && tar -xzf input.tar.gz && sbatch --parsable run.sbatch" | tee "$EVID/job-id.txt"
