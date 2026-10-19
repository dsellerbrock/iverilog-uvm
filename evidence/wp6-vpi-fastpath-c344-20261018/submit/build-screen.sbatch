#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-c344-build
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r1
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
INPUT=$ROOT/input
RESULTS=$ROOT/build
mkdir -p "$ROOT"/{source,install,logs,submit,input,build,callgrind} "$RESULTS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
test -s "$INPUT/candidate.patch"
test -s "$INPUT/run_json_callgrind.py"
(
  cd "$INPUT"
  sha256sum --check SHA256SUMS
)
for side in reference candidate; do
  SOURCE=$ROOT/source/$side
  INSTALL=$ROOT/install/$side
  git clone --no-checkout https://github.com/dsellerbrock/iverilog-uvm.git "$SOURCE" > "$ROOT/logs/clone-$side.log" 2>&1
  git -C "$SOURCE" checkout --detach "$BASE" > "$ROOT/logs/checkout-$side.log" 2>&1
  git -C "$SOURCE" submodule update --init --recursive --jobs 4 > "$ROOT/logs/submodules-$side.log" 2>&1
  test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
  if [[ "$side" == candidate ]]; then
    git -C "$SOURCE" apply --check "$INPUT/candidate.patch"
    git -C "$SOURCE" apply "$INPUT/candidate.patch" > "$RESULTS/patch.log"
  fi
  (
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$INSTALL" --enable-libveriuser CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 5400s make -j4
    timeout --signal=TERM --kill-after=30s 900s make install
    timeout --signal=TERM --kill-after=30s 900s make installuvm
  ) > "$ROOT/logs/build-$side.log" 2>&1
done

bash "$INPUT/semantic/semantic-check.sh" "$ROOT/install/reference" "$ROOT/install/candidate" "$INPUT/semantic" "$RESULTS/semantic" > "$RESULTS/semantic.log" 2>&1
printf 'measurement_base=%s\ncandidate_base_plus_patch=WP6 #658 code from 3b9101a\n' "$BASE" > "$RESULTS/provenance.txt"
cat "$INPUT/source-provenance.txt" >> "$RESULTS/provenance.txt"
sha256sum "$INPUT/candidate.patch" "$ROOT/install/reference/bin/iverilog" "$ROOT/install/reference/bin/vvp" \
  "$ROOT/install/candidate/bin/iverilog" "$ROOT/install/candidate/bin/vvp" > "$RESULTS/binaries.sha256"
touch "$RESULTS/BUILD_SUCCESS"
