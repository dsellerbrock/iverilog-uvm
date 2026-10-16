#!/usr/bin/env bash
#SBATCH --job-name=a5-pd-final-gates
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-gates-845f54a-20261016-r1/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-gates-845f54a-20261016-r1/logs/%x-%j.err
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-gates-845f54a-20261016-r1
ARCHIVES="$RUN/archives"
BASE="$RUN/source-base"
CAND="$RUN/source-candidate"
BASE_INSTALL="$RUN/install-base"
CAND_INSTALL="$RUN/install-candidate"
CANDIDATE=$(cat "$ARCHIVES/candidate.commit")
mkdir -p "$RUN/logs" "$RUN/results" "$BASE/uvm-core" "$CAND/uvm-core"
cd "$RUN"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RUN/results/job-exit-code"
  touch "$RUN/results/DONE"
  find "$RUN/logs" "$RUN/results" "$RUN/gate-summary.txt" -type f ! -path "$RUN/results/SHA256SUMS" -print0 | sort -z | xargs -0 sha256sum > "$RUN/results/SHA256SUMS"
  exit "$rc"
}
trap finish EXIT
(cd "$ARCHIVES" && sha256sum -c SHA256SUMS)
printf 'pinned_campaign_base=%s\nmeasurement_base=%s\ncandidate=%s\nuvm_core=%s\nresources=4 CPUs, 8 GiB, 4 hours\n' \
  'c7ebca768c21c251d9c165c9aff0e363768030b1' \
  '845f54a5724c4d2af13dde40eca6d290c80c41d9' \
  "$CANDIDATE" \
  '78c06547a2a0a29b3dc9dcafae62b75b2ff61544' > "$RUN/gate-summary.txt"
{
  printf 'host=%s\ndate_utc=%s\nkernel=%s\n' "$(hostname)" "$(date -u +%FT%TZ)" "$(uname -a)"
  gcc --version
  g++ --version
  make --version
  bison --version
  flex --version
  gperf --version
  python3 --version
  perl -v
} > "$RUN/logs/tool-version.log" 2>&1
sha256sum "$0" > "$RUN/logs/runner.sha256"

run_gate() {
  local name="$1" limit="$2" rc=0
  shift 2
  {
    printf 'command='
    printf '%q ' "$@"
    printf '\n'
  } > "$RUN/logs/$name.command"
  printf 'BEGIN %s %s\n' "$name" "$(date -u +%FT%TZ)" | tee -a "$RUN/gate-summary.txt"
  set +e
  /usr/bin/time -v -o "$RUN/logs/$name.resource" \
    timeout --signal=TERM --kill-after=15s "$limit" "$@" \
    > "$RUN/logs/$name.log" 2>&1
  rc=$?
  set -e
  printf 'exit_code=%s\n' "$rc" > "$RUN/logs/$name.status"
  printf 'END %s exit_code=%s %s\n' "$name" "$rc" "$(date -u +%FT%TZ)" | tee -a "$RUN/gate-summary.txt"
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAILED_GATE=%s\n' "$name" >> "$RUN/gate-summary.txt"
    exit "$rc"
  fi
}

run_gate extract-base 300s tar -xzf "$ARCHIVES/base.tar.gz" -C "$BASE"
run_gate extract-candidate 300s tar -xzf "$ARCHIVES/candidate.tar.gz" -C "$CAND"
run_gate extract-uvm-base 120s tar -xzf "$ARCHIVES/uvm-core.tar.gz" -C "$BASE/uvm-core"
run_gate extract-uvm-candidate 120s tar -xzf "$ARCHIVES/uvm-core.tar.gz" -C "$CAND/uvm-core"
export CFLAGS='-g0 -O2'
export CXXFLAGS='-g0 -O2'
run_gate autoconf-base 600s bash -c 'cd "$1" && sh ./autoconf.sh' bash "$BASE"
run_gate configure-base 900s bash -c 'cd "$1" && ./configure --prefix="$2" --enable-libveriuser' bash "$BASE" "$BASE_INSTALL"
run_gate build-base 3600s make -C "$BASE" -j4
run_gate install-base 600s make -C "$BASE" install
run_gate fpga-install-base 900s make -C "$BASE/tgt-fpga" install
run_gate autoconf-candidate 600s bash -c 'cd "$1" && sh ./autoconf.sh' bash "$CAND"
run_gate configure-candidate 900s bash -c 'cd "$1" && ./configure --prefix="$2" --enable-libveriuser' bash "$CAND" "$CAND_INSTALL"
run_gate build-candidate 3600s make -C "$CAND" -j4
run_gate install-candidate 600s make -C "$CAND" install
run_gate fpga-install-candidate 900s make -C "$CAND/tgt-fpga" install
export PATH="$CAND_INSTALL/bin:$PATH"
export IVERILOG="$CAND_INSTALL/bin/iverilog"
export VVP="$CAND_INSTALL/bin/vvp"
{
  sha256sum "$CAND_INSTALL/bin/iverilog" "$CAND_INSTALL/lib/ivl/ivl" "$CAND_INSTALL/bin/vvp" "$CAND_INSTALL/lib/ivl/vvp.tgt"
} > "$RUN/logs/candidate-binaries.sha256"
run_gate make-check 7200s make -C "$CAND" check
run_gate ivtest-gate 10800s bash "$CAND/.github/ivtest_gate.sh"
sed -n '/=== JSON ivtest sweep (vvp_reg.py) ===/,$p' "$RUN/logs/ivtest-gate.log" \
  | grep -E '^Test results: Ran [0-9]+, Failed 0' | tail -1 \
  > "$RUN/logs/json-summary.txt"
if [[ ! -s "$RUN/logs/json-summary.txt" ]]; then
  printf 'FAILED_GATE=json-suite-summary-missing-or-failed\n' >> "$RUN/gate-summary.txt"
  exit 1
fi
cat "$RUN/logs/json-summary.txt" | tee -a "$RUN/gate-summary.txt"
run_gate uvm-regression 10800s bash -c 'cd "$1" && bash .github/uvm_test.sh' bash "$CAND"
grep -F 'DPI mode: REAL DPI umbrella loaded' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-dpi-proof.txt"
if grep -Fq 'FALLBACK' "$RUN/logs/uvm-regression.log"; then
  printf 'FAILED_GATE=uvm-real-dpi\n' >> "$RUN/gate-summary.txt"
  exit 1
fi
grep -E 'UVM regression: [0-9]+ passed, 0 failed, [0-9]+ skipped' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-summary.txt"
printf 'all_required_gates=PASS\n' | tee -a "$RUN/gate-summary.txt"
printf 'full_correctness_gates=PASS\n' >> "$RUN/gate-summary.txt"
