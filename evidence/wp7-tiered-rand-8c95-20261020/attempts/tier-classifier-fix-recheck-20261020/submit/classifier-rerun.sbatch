#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-statsrecheck
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tier-classifier-fix-recheck-20261020
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tier-classifier-fix-recheck-20261020/logs/%x-%j.out
set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tier-classifier-fix-recheck-20261020
PREV=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tier-classifier-fix-20261020
SOURCE=$PREV/source/stats
REF=$PREV/install/reference
STATS=$PREV/install/stats
finish() { rc=$?; trap - EXIT; printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"; touch "$ROOT/results/DONE"; exit "$rc"; }
trap finish EXIT
mkdir -p "$ROOT"/{input,logs,results}
sha256sum -c "$ROOT/input/SHA256SUMS"
test "$(cat "$ROOT/input/source.commit")" = fdb1fd05c26536c79b40bfa30c0c0988c1b768ae
bash "$SOURCE/benchmarks/sim-hotspots/test_perf_stats.sh" \
  "$STATS/bin/iverilog" "$REF/bin/vvp" "$STATS/bin/vvp" \
  > "$ROOT/logs/test-perf-stats.log" 2>&1
python3 "$ROOT/input/collect_tier_hist.py" "$SOURCE" "$STATS" "$ROOT/results/histogram" \
  > "$ROOT/logs/tier-hist-corpus.log" 2>&1
find "$ROOT/results" "$ROOT/logs" -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > "$ROOT/results/SHA256SUMS"
tar -czf "$ROOT/classifier-results.tgz" -C "$ROOT" results logs
