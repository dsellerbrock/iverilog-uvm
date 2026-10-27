#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-t1-hull-r1
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-hull-cache-20261021-r1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-hull-cache-20261021-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-hull-cache-20261021-r1
PREVIOUS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-session-interval-cache-20261021-r2
BASE=10f3a0a2509d0852c2556cb6622fb0025121fb2d
PR_HEAD=02acbc6ae38f6b4300a158bf20787e46121484ea
BRANCH=agent/a5-perf-m5-wp7-t1-20261021
GITHUB=https://github.com/dsellerbrock/iverilog-uvm.git
INPUT=$ROOT/input
unset IVL_PERF_STATS
mkdir -p "$ROOT"/{source,install,logs,results,profiles,programs}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    if (( rc == 0 )); then touch "$ROOT/results/SUCCESS"; fi
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

(cd "$INPUT" && sha256sum --check SHA256SUMS)
gzip -dc "$INPUT/t1-hull-cache.patch.gz" > "$INPUT/t1-hull-cache.patch"
test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
cp -a "$PREVIOUS/install/reference" "$ROOT/install/"
cp -a "$PREVIOUS/install/current" "$ROOT/install/"
cp "$PREVIOUS/programs/randomize_dv_txn.vvp" \
    "$PREVIOUS/programs/randomize_z3.vvp" "$ROOT/programs/"
for side in reference current; do
    old="$PREVIOUS/install/$side/bin/vvp"
    expected=$(awk -v path="$old" '$2 == path {print $1}' \
        "$PREVIOUS/results/binaries-$side.sha256")
    test -n "$expected"
    test "$(sha256sum "$ROOT/install/$side/bin/vvp" | awk '{print $1}')" = "$expected"
done
sha256sum "$ROOT/programs"/*.vvp > "$ROOT/results/programs.sha256"

git clone --no-checkout --branch "$BRANCH" --single-branch "$GITHUB" \
    "$ROOT/source/candidate" > "$ROOT/logs/clone-candidate.log" 2>&1
git -C "$ROOT/source/candidate" checkout "$PR_HEAD" \
    > "$ROOT/logs/checkout-candidate.log" 2>&1
test "$(git -C "$ROOT/source/candidate" rev-parse HEAD)" = "$PR_HEAD"
git -C "$ROOT/source/candidate" apply --check \
    "$INPUT/t1-hull-cache.patch"
git -C "$ROOT/source/candidate" apply \
    "$INPUT/t1-hull-cache.patch" > "$ROOT/logs/patch-candidate.log"
git -C "$ROOT/source/candidate" submodule update --init --recursive --jobs 4 \
    > "$ROOT/logs/submodules-candidate.log" 2>&1
PREFIX=$ROOT/install/candidate SOURCE=$ROOT/source/candidate bash -c '
    set -Eeuo pipefail
    cd "$SOURCE"
    unset INSTALL
    sh autoconf.sh
    ./configure --prefix="$PREFIX" --enable-libveriuser --enable-perf-stats \
        CFLAGS="-g -O2 -fno-omit-frame-pointer" \
        CXXFLAGS="-g -O2 -fno-omit-frame-pointer"
    timeout --signal=TERM --kill-after=30s 3600s make -j4
    timeout --signal=TERM --kill-after=30s 900s make install
' > "$ROOT/logs/build-candidate.log" 2>&1
sha256sum "$ROOT/install/candidate/bin/iverilog" \
    "$ROOT/install/candidate/bin/vvp" > "$ROOT/results/binaries-candidate.sha256"

SIDES=(reference current candidate)
for name in randomize_dv_txn randomize_z3; do
    for side in "${SIDES[@]}"; do
        out=$ROOT/results/$name-$side
        timeout --signal=TERM --kill-after=10s 1200s \
            "$ROOT/install/$side/bin/vvp" -n "$ROOT/programs/$name.vvp" \
            > "$out.out" 2> "$out.err"
    done
    for side in current candidate; do
        cmp "$ROOT/results/$name-reference.out" "$ROOT/results/$name-$side.out"
        cmp "$ROOT/results/$name-reference.err" "$ROOT/results/$name-$side.err"
    done
done

SEEDS=(1 2 17 42 2026 324508639 610839777 1234567890)
printf '%s\n' "${SEEDS[@]}" > "$ROOT/results/multiseed-list.txt"
for seed in "${SEEDS[@]}"; do
    for name in randomize_dv_txn randomize_z3; do
        for side in "${SIDES[@]}"; do
            out=$ROOT/results/$name-seed-$seed-$side
            timeout --signal=TERM --kill-after=10s 600s \
                "$ROOT/install/$side/bin/vvp" -n "$ROOT/programs/$name.vvp" \
                "+seed=$seed" > "$out.out" 2> "$out.err"
        done
        for side in current candidate; do
            cmp "$ROOT/results/$name-seed-$seed-reference.out" \
                "$ROOT/results/$name-seed-$seed-$side.out"
            cmp "$ROOT/results/$name-seed-$seed-reference.err" \
                "$ROOT/results/$name-seed-$seed-$side.err"
        done
    done
done

IVL_PERF_STATS=1 timeout --signal=TERM --kill-after=10s 1200s \
    "$ROOT/install/candidate/bin/vvp" -n "$ROOT/programs/randomize_dv_txn.vvp" \
    > "$ROOT/results/randomize_dv_txn-stats.out" \
    2> "$ROOT/results/randomize_dv_txn-stats.err"
sed -n 's/^VVP_PERF_STATS //p' "$ROOT/results/randomize_dv_txn-stats.err" \
    > "$ROOT/results/randomize_dv_txn-stats.json"
test "$(wc -l < "$ROOT/results/randomize_dv_txn-stats.json")" -eq 1

CPU=$(awk '/^Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'base=%s\ncurrent_head=%s\ncandidate_delta=%s\nprebuilt_source=job-3816\ncpu=%s\ncpus_per_task=4\n' \
    "$BASE" "$PR_HEAD" "$(sha256sum "$INPUT/t1-hull-cache.patch" | awk '{print $1}')" \
    "$CPU" > "$ROOT/results/provenance.txt"

for name in randomize_dv_txn randomize_z3; do
    for side in reference current candidate; do
        timeout --signal=TERM --kill-after=20s 3600s taskset -c "$CPU" \
            /usr/bin/valgrind --quiet --tool=callgrind \
            --callgrind-out-file="$ROOT/profiles/$name-$side.callgrind" \
            --log-file="$ROOT/profiles/$name-$side.valgrind.log" \
            "$ROOT/install/$side/bin/vvp" -n "$ROOT/programs/$name.vvp" \
            > "$ROOT/results/$name-$side.callgrind.out" \
            2> "$ROOT/results/$name-$side.callgrind.err"
        cmp "$ROOT/results/$name-reference.out" \
            "$ROOT/results/$name-$side.callgrind.out"
        cmp "$ROOT/results/$name-reference.err" \
            "$ROOT/results/$name-$side.callgrind.err"
        awk '/^summary:/ {print $2}' "$ROOT/profiles/$name-$side.callgrind" \
            > "$ROOT/results/$name-$side.instructions"
        test "$(wc -l < "$ROOT/results/$name-$side.instructions")" -eq 1
    done
done

python3 - "$ROOT/results" <<'PY'
import pathlib, sys
r = pathlib.Path(sys.argv[1])
rows = ["workload,base,current_pr,candidate,candidate_vs_current_pr"]
accepted = True
for name in ("randomize_dv_txn", "randomize_z3"):
    counts = [int((r / f"{name}-{side}.instructions").read_text().strip())
              for side in ("reference", "current", "candidate")]
    speed = counts[1] / counts[2]
    rows.append(f"{name},{counts[0]},{counts[1]},{counts[2]},{speed:.6f}x")
    if name == "randomize_dv_txn":
        accepted &= speed >= 1.10
    else:
        accepted &= speed >= 0.98
(r / "screen.csv").write_text("\n".join(rows) + "\n")
(r / "screen-decision.txt").write_text(
    "promote" if accepted else "reject: target gain/regression threshold not met")
PY
cat "$ROOT/results/screen.csv"
cat "$ROOT/results/screen-decision.txt"
touch "$ROOT/results/SUCCESS"
