#!/usr/bin/env bash
#SBATCH --job-name=a5-pd-malformed
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-malformed-c7eb-20261015-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-malformed-c7eb-20261015-r1/logs/%x-%j.out

set -Eeuo pipefail
RUN_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-malformed-c7eb-20261015-r1
TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/candidate/source
CAND=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/build/candidate/install
RESULTS=$RUN_ROOT/results
mkdir -p "$RUN_ROOT/logs" "$RESULTS" "$RUN_ROOT/source/tests/vvp_runtime" \
    "$RUN_ROOT/source/ivtest/ivltests"
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT
cp "$RUN_ROOT/input/run_property_index_metadata_malformed.sh" \
    "$RUN_ROOT/source/tests/vvp_runtime/"
cp "$TEMPLATE/ivtest/ivltests/sv_class_unpacked_property_index_4state.v" \
    "$RUN_ROOT/source/ivtest/ivltests/"
export IVERILOG="$CAND/bin/iverilog"
export VVP="$CAND/bin/vvp"
export IVERILOG_BIN="$CAND/bin/iverilog"
export VVP_BIN="$CAND/bin/vvp"
printf 'measurement_base=c7ebca768c21c251d9c165c9aff0e363768030b1\n' \
    > "$RESULTS/provenance.txt"
sha256sum "$CAND/bin/iverilog" "$CAND/bin/vvp" \
    "$RUN_ROOT/source/tests/vvp_runtime/run_property_index_metadata_malformed.sh" \
    "$RUN_ROOT/source/ivtest/ivltests/sv_class_unpacked_property_index_4state.v" \
    >> "$RESULTS/provenance.txt"
cd "$RUN_ROOT/source"
timeout --signal=TERM --kill-after=10s 120s \
    sh tests/vvp_runtime/run_property_index_metadata_malformed.sh \
    > "$RUN_ROOT/logs/malformed-check.log" 2>&1
cat "$RUN_ROOT/logs/malformed-check.log"
