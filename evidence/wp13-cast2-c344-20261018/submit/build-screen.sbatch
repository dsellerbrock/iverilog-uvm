#!/usr/bin/env bash
#SBATCH --job-name=a5-wp13-cast2-build
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-cast2-c344-20261018-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-cast2-c344-20261018-r1/logs/%x-%j.out
set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-cast2-c344-20261018-r1
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-current-main-profile-20261017/source
INPUT=$ROOT/input
RESULTS=$ROOT/build-screen
mkdir -p "$ROOT"/{source,install,logs,submit,input} "$RESULTS"
finish() { local rc=$?; trap - EXIT; printf '%s\n' "$rc" > "$RESULTS/job-exit-code"; touch "$RESULTS/DONE"; exit "$rc"; }
trap finish EXIT
test "$(cat "$INPUT/source.commit")" = "$BASE"
test "$(git -C "$TEMPLATE" rev-parse "$BASE^{commit}")" = "$BASE"
test -f "$INPUT/candidate.patch" && test -f "$INPUT/cast2-guard.sv"
for side in reference candidate; do
  SOURCE=$ROOT/source/$side
  INSTALL=$ROOT/install/$side
  git clone --shared --no-checkout "$TEMPLATE" "$SOURCE" > "$ROOT/logs/clone-$side.log" 2>&1
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
  "$INSTALL/bin/iverilog" -g2012 -s check -o "$RESULTS/$side-guard.vvp" "$INPUT/cast2-guard.sv"
  "$INSTALL/bin/vvp" "$RESULTS/$side-guard.vvp" > "$RESULTS/$side-guard.log"
done
diff -u "$RESULTS/reference-guard.log" "$RESULTS/candidate-guard.log" > "$RESULTS/guard-output.diff"
test "$(cat "$RESULTS/candidate-guard.log")" = PASS
python3 - "$RESULTS/reference-guard.vvp" "$RESULTS/candidate-guard.vvp" > "$RESULTS/guard-cast-counts.txt" <<'PY'
from pathlib import Path
import sys
needle = "cast2; compound l-value read"
counts = [Path(path).read_text().count(needle) for path in sys.argv[1:]]
if counts[1] >= counts[0]:
    raise SystemExit(f"cast2 guard did not reduce: reference={counts[0]} candidate={counts[1]}")
print(f"reference={counts[0]} candidate={counts[1]}")
PY
printf 'base=%s\n' "$BASE" > "$RESULTS/provenance.txt"
sha256sum "$INPUT/candidate.patch" "$INPUT/cast2-guard.sv" > "$RESULTS/input.sha256"
sha256sum "$ROOT/install/reference/bin/iverilog" "$ROOT/install/reference/bin/vvp" "$ROOT/install/candidate/bin/iverilog" "$ROOT/install/candidate/bin/vvp" > "$RESULTS/binaries.sha256"
touch "$RESULTS/BUILD_SUCCESS"
