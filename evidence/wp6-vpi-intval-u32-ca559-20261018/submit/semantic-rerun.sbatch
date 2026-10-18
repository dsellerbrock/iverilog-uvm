#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-vpi-u32-sem
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:15:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-intval-u32-gates-ca559-20261018-r1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-intval-u32-gates-ca559-20261018-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-intval-u32-gates-ca559-20261018-r1
BASE=ca559fd97b19bd6a56cc10f0faf8583b4077975f
REF=/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile
CAND=$ROOT/install/candidate
SEMANTIC=$ROOT/semantic
RESULTS=$ROOT/semantic-rerun
mkdir -p "$RESULTS/out"
finish() {
    local rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C "$ROOT/source/candidate" rev-parse HEAD)" = "$BASE"
test -x "$REF/bin/vvp" && test -x "$CAND/bin/vvp"
test -f "$SEMANTIC/semantic-check.sh" && test -f "$SEMANTIC/check-intval.sh"
/usr/bin/time -v -o "$RESULTS/time.txt" \
    python3 "$ROOT/source/candidate/scripts/run_with_timeout.py" 600 -- \
    bash "$SEMANTIC/semantic-check.sh" "$REF" "$CAND" "$SEMANTIC" "$RESULTS/out" \
    > "$RESULTS/semantic.log" 2>&1
sha256sum "$REF/bin/vvp" "$CAND/bin/vvp" "$RESULTS/out/reference.out" \
    "$RESULTS/out/candidate.out" > "$RESULTS/SHA256SUMS"
printf 'measurement_base=%s\nsource_head=%s\n' "$BASE" \
    "$(git -C "$ROOT/source/candidate" rev-parse HEAD)" > "$RESULTS/provenance.txt"
touch "$RESULTS/SUCCESS"
