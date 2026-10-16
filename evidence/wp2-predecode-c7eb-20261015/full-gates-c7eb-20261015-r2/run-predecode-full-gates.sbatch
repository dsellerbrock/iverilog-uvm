#!/usr/bin/env bash
#SBATCH --job-name=a5-pd-gates
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-gates-c7eb-20261015-r2/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-gates-c7eb-20261015-r2/logs/%x-%j.err
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-gates-c7eb-20261015-r2
ARCHIVES="$RUN/archives"
BASE="$RUN/source-base"
CAND="$RUN/source-candidate"
BASE_INSTALL="$RUN/install-base"
CAND_INSTALL="$RUN/install-candidate"
mkdir -p "$RUN/logs" "$RUN/json" "$RUN/results" "$BASE/uvm-core" "$CAND/uvm-core"
cd "$RUN"
(cd "$ARCHIVES" && sha256sum -c SHA256SUMS)
printf 'measurement_base=%s\ncandidate=%s\nuvm_core=%s\nresources=4 CPUs, 8 GiB, 4 hours\n' \
  'c7ebca768c21c251d9c165c9aff0e363768030b1' \
  '4f4ec93c86ce6d767ec4639d22213ef7dc05cfc9' \
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
sha256sum "$0" "$RUN/run-json-isolated.py" > "$RUN/logs/runner.sha256"

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
run_gate json-candidate 10800s python3 "$RUN/run-json-isolated.py" --source "$CAND" --install "$CAND_INSTALL" --output "$RUN/json/candidate" --timeout-seconds 300
if [[ -s "$RUN/json/candidate/failures.txt" ]]; then
  run_gate json-baseline-targeted 7200s python3 "$RUN/run-json-isolated.py" --source "$BASE" --install "$BASE_INSTALL" --output "$RUN/json/baseline" --names-file "$RUN/json/candidate/failures.txt" --timeout-seconds 300
else
  mkdir -p "$RUN/json/baseline"
  : > "$RUN/json/baseline/failures.txt"
fi
comm -23 <(sort -u "$RUN/json/candidate/failures.txt") <(sort -u "$RUN/json/baseline/failures.txt") > "$RUN/json/new-failures.txt"
if [[ -s "$RUN/json/new-failures.txt" ]]; then
  printf 'FAILED_GATE=json-baseline-delta\n' >> "$RUN/gate-summary.txt"
  cat "$RUN/json/new-failures.txt" >> "$RUN/gate-summary.txt"
  exit 1
fi
printf 'json_candidate=%s tests, baseline_failures=%s, new_failures=0\n' \
  "$(cut -d= -f2 "$RUN/json/candidate/summary.txt" | head -n 1)" \
  "$(wc -l < "$RUN/json/candidate/failures.txt" | tr -d ' ')" | tee -a "$RUN/gate-summary.txt"
run_gate uvm-regression 10800s bash -c 'cd "$1" && bash .github/uvm_test.sh' bash "$CAND"
grep -F 'DPI mode: REAL DPI umbrella loaded' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-dpi-proof.txt"
if grep -Fq 'FALLBACK' "$RUN/logs/uvm-regression.log"; then
  printf 'FAILED_GATE=uvm-real-dpi\n' >> "$RUN/gate-summary.txt"
  exit 1
fi
grep -E 'UVM regression: [0-9]+ passed, 0 failed, [0-9]+ skipped' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-summary.txt"
printf 'all_required_gates=PASS\n' | tee -a "$RUN/gate-summary.txt"
printf '0\n' > "$RUN/results/job-exit-code"
touch "$RUN/results/DONE"
find "$RUN/logs" "$RUN/json" "$RUN/results" -type f -print0 | sort -z | xargs -0 sha256sum > "$RUN/results/SHA256SUMS"
