#!/usr/bin/env bash
set -Eeuo pipefail

JOB=$1
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-top-throughput-r2-20261016
LOG=$ROOT/logs/a5-caliptra-throughput-r2-$JOB.out
last_state=$(squeue -h -j "$JOB" -o %T || true)
printf 'job=%s initial_state=%s\n' "$JOB" "$last_state"
loops=0

while [[ ! -e "$ROOT/results/DONE" ]]; do
    sleep 300
    state=$(squeue -h -j "$JOB" -o %T || true)
    if [[ "$state" != "$last_state" ]]; then
        printf 'state_change=%s->%s\n' "$last_state" "$state"
        last_state=$state
    fi
    loops=$((loops + 1))
    if (( loops % 3 == 0 )); then
        tail -n 30 "$LOG" 2>/dev/null || true
    fi
    if [[ -z "$state" && ! -e "$ROOT/results/DONE" ]]; then
        printf 'job left squeue before writing DONE\n'
        break
    fi
done

if [[ -e "$ROOT/results/job-exit-code" ]]; then
    printf 'job_exit='
    cat "$ROOT/results/job-exit-code"
fi
tail -n 40 "$LOG" 2>/dev/null || true
