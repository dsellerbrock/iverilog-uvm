#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-full-gates
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020
BASE=8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1
SOURCE=$ROOT/source/candidate
REF_INSTALL=$ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
INPUT=$ROOT/input
RESULTS=$ROOT/gates-wp7
LOGS=$ROOT/logs/gates-wp7
overall=0
mkdir -p "$LOGS" "$RESULTS"
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    if (( rc == 0 )); then touch "$RESULTS/SUCCESS"; fi
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
git -C "$SOURCE" add -N benchmarks/sim-hotspots/randomize_t0_disabled.sv \
    docs/performance/SOLVER.md
git -C "$SOURCE" diff --binary HEAD > "$RESULTS/candidate.patch"
cmp "$RESULTS/candidate.patch" "$INPUT/candidate.patch"

export PATH="$CAND_INSTALL/bin:$PATH"
export IVERILOG="$CAND_INSTALL/bin/iverilog" VVP="$CAND_INSTALL/bin/vvp"
export IVERILOG_VPI="$CAND_INSTALL/bin/iverilog-vpi"
export UVM_DPI="$CAND_INSTALL/lib/ivl/uvm_dpi.vpi"
{
    hostname
    uname -a
    printf 'measurement_base=%s\n' "$BASE"
    git -C "$SOURCE" status --short
    sha256sum "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" "$INPUT/candidate.patch"
} > "$ROOT/gates-provenance.txt"

run_stage() {
    local name=$1 limit=$2 rc
    shift 2
    if /usr/bin/time -v -o "$LOGS/$name.time" \
        python3 "$SOURCE/scripts/run_with_timeout.py" "$limit" -- "$@" \
        > "$LOGS/$name.log" 2>&1; then
        rc=0
    else
        rc=$?
        overall=1
    fi
    printf '%s\t%s\n' "$name" "$rc" >> "$RESULTS/stage-status.tsv"
}

: > "$RESULTS/stage-status.tsv"
run_stage make-check 5400 make -C "$SOURCE" -j4 check
run_stage tgt-fpga-install 600 make -C "$SOURCE/tgt-fpga" install
run_stage ivtest-gate 14400 bash "$SOURCE/.github/ivtest_gate.sh"
run_stage uvm-real-dpi 14400 bash -c 'set -euo pipefail; cd "$1"; exec bash .github/uvm_test.sh' _ "$SOURCE"
(cd "$ROOT" && find gates-wp7 -type f ! -name SHA256SUMS -print0 \
    | sort -z | xargs -0 sha256sum) > "$RESULTS/SHA256SUMS"
exit "$overall"
