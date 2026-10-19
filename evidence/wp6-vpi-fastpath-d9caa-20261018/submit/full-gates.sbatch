#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-d9caa-gates
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
BASE=d9caaaea5b410ed14e7ca14be828fc2f2c9fea44
CANDIDATE=498bf0826b810d5fe8ae560b02903c7bb5558c36
SOURCE=$ROOT/source/candidate
REF_INSTALL=/home/dsell/toolchains/iverilog-uvm-d9caaaea5b410ed14e7ca14be828fc2f2c9fea44-a5-wp6-r2
CAND_INSTALL=$ROOT/install/candidate
INPUT=$ROOT/input
RESULTS=$ROOT/gates
LOGS=$ROOT/logs/gates
overall=0
mkdir -p "$LOGS" "$RESULTS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  if (( rc == 0 )); then touch "$RESULTS/SUCCESS"; fi
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
test "$(cat "$INPUT/candidate.commit")" = "$CANDIDATE"
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
patch --dry-run -R -p1 -d "$SOURCE" < "$INPUT/candidate.patch" > "$RESULTS/patch-check.log"

export PATH="$CAND_INSTALL/bin:$PATH"
export IVERILOG="$CAND_INSTALL/bin/iverilog" VVP="$CAND_INSTALL/bin/vvp"
export IVERILOG_VPI="$CAND_INSTALL/bin/iverilog-vpi" UVM_DPI="$CAND_INSTALL/lib/ivl/uvm_dpi.vpi"
{
  hostname
  uname -a
  printf 'measurement_base=%s\ncandidate_commit=%s\n' "$BASE" "$CANDIDATE"
  cat "$INPUT/source-provenance.txt"
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
run_stage vpi-intval-semantics 600 bash "$INPUT/semantic-check.sh" \
  "$REF_INSTALL" "$CAND_INSTALL" "$INPUT/semantic" "$RESULTS/semantic"
run_stage make-check 5400 make -C "$SOURCE" -j4 check
run_stage tgt-fpga-install 600 make -C "$SOURCE/tgt-fpga" install
run_stage ivtest-gate 14400 bash "$SOURCE/.github/ivtest_gate.sh"
run_stage uvm-real-dpi 14400 bash -c 'set -euo pipefail; cd "$1"; exec bash .github/uvm_test.sh' _ "$SOURCE"
sha256sum "$ROOT/gates-provenance.txt" "$RESULTS/stage-status.tsv" \
  "$LOGS"/*.log "$LOGS"/*.time > "$RESULTS/SHA256SUMS"
exit "$overall"
