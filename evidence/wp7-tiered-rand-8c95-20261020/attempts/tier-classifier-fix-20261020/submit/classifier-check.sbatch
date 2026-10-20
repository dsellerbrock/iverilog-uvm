#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-statsfix
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tier-classifier-fix-20261020
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tier-classifier-fix-20261020/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tier-classifier-fix-20261020
PARENT=fdb1fd05c26536c79b40bfa30c0c0988c1b768ae
SOURCE=$ROOT/source
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT
mkdir -p "$ROOT"/{source,install,logs,results}
test "$PARENT" = "$(cat "$ROOT/input/source.commit")"
sha256sum -c "$ROOT/input/SHA256SUMS"
for side in reference stats; do
    src=$SOURCE/$side
    prefix=$ROOT/install/$side
    git clone --filter=blob:none --no-checkout https://github.com/dsellerbrock/iverilog-uvm.git "$src" \
        > "$ROOT/logs/clone-$side.log" 2>&1
    git -C "$src" checkout --detach "$PARENT" > "$ROOT/logs/checkout-$side.log" 2>&1
    git -C "$src" apply "$ROOT/input/classifier.patch"
    git -C "$src" submodule update --init --recursive --jobs 4 > "$ROOT/logs/submodules-$side.log" 2>&1
    printf 'side=%s\nparent=%s\n' "$side" "$PARENT" >> "$ROOT/results/provenance.txt"
    git -C "$src" submodule status --recursive >> "$ROOT/results/provenance.txt"
    flags=(--enable-libveriuser)
    if [[ "$side" == stats ]]; then flags+=(--enable-perf-stats); fi
    (
        cd "$src"
        sh autoconf.sh
        ./configure "${flags[@]}" --prefix="$prefix" CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
        timeout --signal=TERM --kill-after=30s 3600s make -j4
        timeout --signal=TERM --kill-after=30s 900s make install
        timeout --signal=TERM --kill-after=30s 900s make installuvm
    ) > "$ROOT/logs/build-$side.log" 2>&1
done
bash "$SOURCE/stats/benchmarks/sim-hotspots/test_perf_stats.sh" \
    "$ROOT/install/stats/bin/iverilog" "$ROOT/install/reference/bin/vvp" \
    "$ROOT/install/stats/bin/vvp" > "$ROOT/logs/test-perf-stats.log" 2>&1
python3 "$SOURCE/stats/benchmarks/sim-hotspots/collect_tier_hist.py" \
    "$SOURCE/stats" "$ROOT/install/stats" "$ROOT/results/tier-hist-corpus" \
    > "$ROOT/logs/tier-hist-corpus.log" 2>&1
find "$ROOT/results" "$ROOT/logs" -type f ! -name SHA256SUMS -print0 | sort -z \
    | xargs -0 sha256sum > "$ROOT/results/SHA256SUMS"
tar -czf "$ROOT/tier-classifier-fix.tgz" -C "$ROOT" results logs/test-perf-stats.log logs/tier-hist-corpus.log
