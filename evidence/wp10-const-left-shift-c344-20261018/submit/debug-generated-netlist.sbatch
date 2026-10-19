#!/usr/bin/env bash
#SBATCH --job-name=a5-wp10-debug
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-const-left-shift-c344-20261018/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-const-left-shift-c344-20261018/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-const-left-shift-c344-20261018
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
SOURCE=$ROOT/source/candidate
REF_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r3
REF_INSTALL=$REF_ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
RESULTS=$ROOT/results/debug-netlist
SEMANTIC=$SOURCE/evidence/wp10-const-left-shift-c344-20261018/input/semantic

mkdir -p "$RESULTS"
finish() {
  rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/debug-job-exit-code"
  touch "$RESULTS/debug-DONE"
  exit "$rc"
}
trap finish EXIT
test "$(cat "$ROOT/input/measurement-base.txt")" = "$BASE"
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$(cat "$ROOT/input/candidate.commit")"

"$REF_INSTALL/bin/iverilog" -g2012 -o "$RESULTS/shift.reference.vvp" \
    "$SEMANTIC/shift_semantics.sv" > "$RESULTS/compile-reference.log" 2>&1
"$CAND_INSTALL/bin/iverilog" -g2012 -o "$RESULTS/shift.candidate.vvp" \
    "$SEMANTIC/shift_semantics.sv" > "$RESULTS/compile-candidate.log" 2>&1
"$REF_INSTALL/bin/iverilog" -g2012 -o "$RESULTS/rtl_pipe.reference.vvp" \
    "$SOURCE/benchmarks/sim-hotspots/rtl_pipe.sv" > "$RESULTS/pipe-reference.log" 2>&1
"$CAND_INSTALL/bin/iverilog" -g2012 -o "$RESULTS/rtl_pipe.candidate.vvp" \
    "$SOURCE/benchmarks/sim-hotspots/rtl_pipe.sv" > "$RESULTS/pipe-candidate.log" 2>&1

for design in shift rtl_pipe; do
  ref=$RESULTS/$design.reference.vvp
  candidate=$RESULTS/$design.candidate.vvp
  {
    printf '%s reference: part=' "$design"
    grep -c '\.part' "$ref" || true
    printf '%s reference: concat=' "$design"
    grep -c '\.concat' "$ref" || true
    printf '%s reference: shift/l=' "$design"
    grep -c '\.shift/l' "$ref" || true
    printf '%s candidate: part=' "$design"
    grep -c '\.part' "$candidate" || true
    printf '%s candidate: concat=' "$design"
    grep -c '\.concat' "$candidate" || true
    printf '%s candidate: shift/l=' "$design"
    grep -c '\.shift/l' "$candidate" || true
  } >> "$RESULTS/netlist-counts.txt"
done

grep -nE '\.part|\.concat|\.shift/l' "$RESULTS/shift.candidate.vvp" \
    > "$RESULTS/shift-candidate-nodes.txt" || true
set +e
bash "$SEMANTIC/check-shift-semantics.sh" "$REF_INSTALL/bin/iverilog" \
    "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/iverilog" \
    "$REF_INSTALL/bin/vvp" > "$RESULTS/semantic.log" 2>&1
semantic_rc=$?
set -e
printf '%s\n' "$semantic_rc" > "$RESULTS/semantic-exit-code"

"$REF_INSTALL/bin/vvp" "$RESULTS/shift.reference.vvp" > "$RESULTS/shift.reference.out" 2>&1
"$REF_INSTALL/bin/vvp" "$RESULTS/shift.candidate.vvp" > "$RESULTS/shift.candidate.out" 2>&1
cmp "$RESULTS/shift.reference.out" "$RESULTS/shift.candidate.out"
"$REF_INSTALL/bin/vvp" "$RESULTS/rtl_pipe.reference.vvp" > "$RESULTS/pipe.reference.out" 2>&1
"$REF_INSTALL/bin/vvp" "$RESULTS/rtl_pipe.candidate.vvp" > "$RESULTS/pipe.candidate.out" 2>&1
cmp "$RESULTS/pipe.reference.out" "$RESULTS/pipe.candidate.out"

printf 'measurement_base=%s\ncandidate_commit=%s\nsemantic_check_exit=%s\n' \
    "$BASE" "$(cat "$ROOT/input/candidate.commit")" "$semantic_rc" \
    > "$RESULTS/provenance.txt"
sha256sum "$RESULTS"/*.vvp "$RESULTS"/*.out "$RESULTS/netlist-counts.txt" \
    > "$RESULTS/SHA256SUMS"
