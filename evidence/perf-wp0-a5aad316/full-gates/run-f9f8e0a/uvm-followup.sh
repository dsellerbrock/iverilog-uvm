#!/usr/bin/env bash
# Re-run only the UVM gate after correcting the harness working directory.
# The source archives are the exact candidate and uvm-core snapshots recorded
# in source-manifest.txt; all build products stay inside this fresh run.
#SBATCH --job-name=a5-wp0-uvm-f9f8
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-uvm-a5aad316-f9f8-20261014-r1/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-uvm-a5aad316-f9f8-20261014-r1/logs/%x-%j.err
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-uvm-a5aad316-f9f8-20261014-r1
SRC="$RUN/source"
INSTALL="$RUN/install"
ARCHIVES="$RUN/archives"
mkdir -p "$RUN/logs" "$SRC" "$SRC/uvm-core" "$INSTALL"
cd "$RUN"
(cd "$ARCHIVES" && sha256sum -c SHA256SUMS)
printf 'base=%s\ncandidate=%s\nuvm_core=%s\n' \
  'f9f8e0a79f230f38da6cbb4445994ad1075ad531' \
  'a5aad31659540d6a4c67bbaeffbeaa484b31f442' \
  '78c06547a2a0a29b3dc9dcafae62b75b2ff61544' > "$RUN/source-manifest.txt"
printf 'candidate_archive_sha256=%s\nuvm_core_archive_sha256=%s\n' \
  'a9115852b201066c951a2fdfa6a91c79a25aa72c3caf8e6b265aded7bce9f53d' \
  '49be835aa19cff7ba99583b1801e98d5fe7405914bbd5f91a26b8431b88540ab' \
  >> "$RUN/source-manifest.txt"
{
  printf 'host=%s\ndate_utc=%s\nkernel=%s\n' "$(hostname)" "$(date -u +%FT%TZ)" "$(uname -a)"
  gcc --version
  g++ --version
  make --version
  bison --version
  flex --version
  gperf --version
  python3 --version
} > "$RUN/logs/tool-version.log" 2>&1
sha256sum "$0" > "$RUN/logs/runner.sha256"

run_gate() {
  local name="$1" limit="$2" rc=0
  shift 2
  printf 'command=' > "$RUN/logs/$name.command"
  printf '%q ' "$@" >> "$RUN/logs/$name.command"
  printf '\n' >> "$RUN/logs/$name.command"
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

run_gate extract-candidate 120s tar -xzf "$ARCHIVES/candidate.tar.gz" -C "$SRC"
run_gate extract-uvm-core 120s tar -xzf "$ARCHIVES/uvm-core.tar.gz" -C "$SRC/uvm-core"
export CFLAGS='-g0 -O2'
export CXXFLAGS='-g0 -O2'
run_gate autoconf 600s bash -c 'cd "$1" && sh ./autoconf.sh' bash "$SRC"
run_gate configure 900s bash -c 'cd "$1" && ./configure --prefix="$2" --enable-libveriuser' bash "$SRC" "$INSTALL"
run_gate build 3600s make -C "$SRC" -j2
run_gate install 600s make -C "$SRC" install
export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog"
export VVP="$INSTALL/bin/vvp"
run_gate uvm-regression 10800s bash -c 'cd "$1" && bash .github/uvm_test.sh' bash "$SRC"
grep -F 'DPI mode: REAL DPI umbrella loaded' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-dpi-proof.txt"
if grep -Fq 'FALLBACK' "$RUN/logs/uvm-regression.log"; then
  printf 'FAIL: UVM runner reported fallback DPI\n' | tee -a "$RUN/gate-summary.txt"
  exit 1
fi
grep -E 'UVM regression: [0-9]+ passed, 0 failed, [0-9]+ skipped' "$RUN/logs/uvm-regression.log" > "$RUN/logs/uvm-summary.txt"
printf 'all_required_gates=PASS\n' | tee -a "$RUN/gate-summary.txt"
sha256sum "$RUN/gate-summary.txt" "$RUN/source-manifest.txt" "$RUN/logs"/* > "$RUN/logs.sha256"
