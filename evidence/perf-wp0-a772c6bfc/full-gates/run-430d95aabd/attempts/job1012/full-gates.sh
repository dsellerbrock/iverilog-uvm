#!/usr/bin/env bash
#SBATCH --job-name=a5-wp0-full-430d-r2
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-430d95aabd-20261014-r2/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-430d95aabd-20261014-r2/logs/%x-%j.err
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-430d95aabd-20261014-r2
ARCHIVES="$RUN/archives"
SRC_OFF="$RUN/source-off"
SRC_ON="$RUN/source-on"
OFF="$RUN/install-off"
ON="$RUN/install-on"
mkdir -p "$RUN/logs" "$RUN/tmp" "$SRC_OFF" "$SRC_ON"
cd "$RUN"
printf 'head=430d95aabd93b9922f5987b108bf27de894aed1d\n' > gate-summary.txt
printf 'resources=4 CPUs, 8 GiB RAM, 4 hours; serial gates after parallel build targets\n' >> gate-summary.txt
(cd "$ARCHIVES" && sha256sum -c SHA256SUMS)
{
  printf 'host=%s\n' "$(hostname)"
  printf 'date_utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'kernel=%s\n' "$(uname -a)"
  gcc --version
  g++ --version
  make --version
  bison --version
  flex --version
  gperf --version
  python3 --version
  perl -v
  nm --version
} > "$RUN/logs/tool-version.log" 2>&1
run_gate() {
  local name="$1"
  local limit="$2"
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
  local rc=$?
  set -e
  printf 'exit_code=%s\n' "$rc" > "$RUN/logs/$name.status"
  printf 'END %s exit_code=%s %s\n' "$name" "$rc" "$(date -u +%FT%TZ)" | tee -a "$RUN/gate-summary.txt"
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAILED_GATE=%s\n' "$name" >> "$RUN/gate-summary.txt"
    exit "$rc"
  fi
}
run_gate extract-off 300s tar -xzf "$ARCHIVES/source.tar.gz" -C "$SRC_OFF"
run_gate extract-on 300s tar -xzf "$ARCHIVES/source.tar.gz" -C "$SRC_ON"
mkdir -p "$SRC_OFF/uvm-core" "$SRC_ON/uvm-core"
run_gate extract-uvm-off 120s tar -xzf "$ARCHIVES/uvm-core.tar.gz" -C "$SRC_OFF/uvm-core"
run_gate extract-uvm-on 120s tar -xzf "$ARCHIVES/uvm-core.tar.gz" -C "$SRC_ON/uvm-core"
export CFLAGS='-g0 -O2'
export CXXFLAGS='-g0 -O2'
run_gate autoconf-off 600s bash -c 'cd "$1" && sh ./autoconf.sh' bash "$SRC_OFF"
run_gate configure-off 900s bash -c 'cd "$1" && ./configure --prefix="$2" --enable-libveriuser' bash "$SRC_OFF" "$OFF"
run_gate build-off 3600s make -C "$SRC_OFF" -j4
run_gate install-off 600s make -C "$SRC_OFF" install
run_gate autoconf-on 600s bash -c 'cd "$1" && sh ./autoconf.sh' bash "$SRC_ON"
run_gate configure-on 900s bash -c 'cd "$1" && ./configure --prefix="$2" --enable-libveriuser --enable-perf-stats' bash "$SRC_ON" "$ON"
run_gate build-on 3600s make -C "$SRC_ON" -j4
run_gate install-on 600s make -C "$SRC_ON" install
nm -C "$OFF/bin/vvp" > "$RUN/logs/vvp-off.nm"
if grep -Fq 'vvp_perf_stats_' "$RUN/logs/vvp-off.nm"; then
  printf 'FAIL: disabled runtime contains performance-counter symbols\n' | tee -a "$RUN/gate-summary.txt"
  exit 1
fi
nm -C "$ON/bin/vvp" > "$RUN/logs/vvp-on.nm"
grep -F 'vvp_perf_stats_' "$RUN/logs/vvp-on.nm" > "$RUN/logs/vvp-on-perf-symbols.txt"
test -s "$RUN/logs/vvp-on-perf-symbols.txt"
printf 'counter_symbols=off_absent,on_present\n' | tee -a "$RUN/gate-summary.txt"
export PATH="$OFF/bin:$PATH"
export IVERILOG="$OFF/bin/iverilog"
export VVP="$OFF/bin/vvp"
run_gate perf-stats-regression 120s bash "$SRC_OFF/benchmarks/sim-hotspots/test_perf_stats.sh" "$OFF/bin/iverilog" "$OFF/bin/vvp" "$ON/bin/vvp"
run_gate make-check 7200s make -C "$SRC_OFF" check
run_gate ivtest-gate 7200s bash "$SRC_OFF/.github/ivtest_gate.sh"
run_gate fpga-install 900s make -C "$SRC_OFF/tgt-fpga" install
run_gate full-json-ivtest 10800s bash -c 'cd "$1/ivtest" && python3 ./vvp_reg.py' bash "$SRC_OFF"
run_gate install-uvm 1800s make -C "$SRC_OFF" installuvm
run_gate uvm-regression 10800s bash "$SRC_OFF/.github/uvm_test.sh"
grep -F 'DPI mode: REAL DPI umbrella loaded' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-dpi-proof.txt"
if grep -Fq 'FALLBACK' "$RUN/logs/uvm-regression.log"; then
  printf 'FAIL: UVM runner reported fallback DPI\n' | tee -a "$RUN/gate-summary.txt"
  exit 1
fi
grep -E 'UVM regression: [0-9]+ passed, 0 failed, [0-9]+ skipped' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-summary.txt"
printf 'all_gates=PASS\n' | tee -a "$RUN/gate-summary.txt"
sha256sum "$RUN/gate-summary.txt" "$RUN/logs"/* > "$RUN/logs.sha256"
