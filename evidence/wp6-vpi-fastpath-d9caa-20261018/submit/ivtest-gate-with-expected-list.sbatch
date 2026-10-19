#!/usr/bin/env bash
# Re-run the full ivtest gate with its tracked expectation manifest included.
# The source archive intentionally omits documentation; this restores only
# the gate's required input, from the exact measurement base.
#SBATCH --job-name=a5-wp6-d9caa-ivgate
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
BASE=d9caaaea5b410ed14e7ca14be828fc2f2c9fea44
EXPECTED_SHA=b22c9f7b117ea0b1644155c2673f27944da404a7b92c0f52a50998f29712c357
SOURCE=$ROOT/source/candidate
INPUT=$ROOT/input/ivtest_expected_fails.list
RESULTS=$ROOT/ivtest-expect-list-replay
CAND_INSTALL=$ROOT/install/candidate
mkdir -p "$RESULTS" "$ROOT/logs" "$SOURCE/docs/conformance"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  if (( rc == 0 )); then touch "$RESULTS/SUCCESS"; fi
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(sha256sum "$INPUT" | awk '{print $1}')" = "$EXPECTED_SHA"
cp "$INPUT" "$SOURCE/docs/conformance/ivtest_expected_fails.list"
test "$(sha256sum "$SOURCE/docs/conformance/ivtest_expected_fails.list" | awk '{print $1}')" = "$EXPECTED_SHA"
{
  printf 'measurement_base=%s\n' "$BASE"
  printf 'candidate_source_commit=498bf0826b810d5fe8ae560b02903c7bb5558c36\n'
  printf 'expected_fail_list_sha256=%s\n' "$EXPECTED_SHA"
  sha256sum "$CAND_INSTALL/bin/vvp" "$CAND_INSTALL/bin/iverilog" "$INPUT"
} > "$RESULTS/provenance.txt"
export PATH="$CAND_INSTALL/bin:$PATH"
export IVERILOG="$CAND_INSTALL/bin/iverilog" VVP="$CAND_INSTALL/bin/vvp"
if (cd "$SOURCE" && bash .github/ivtest_gate.sh) > "$RESULTS/ivtest-gate.log" 2>&1; then
  rc=0
else
  rc=$?
fi
printf '%s\n' "$rc" > "$RESULTS/stage-status.txt"
sha256sum "$RESULTS/provenance.txt" "$RESULTS/stage-status.txt" "$RESULTS/ivtest-gate.log" > "$RESULTS/SHA256SUMS"
exit "$rc"
