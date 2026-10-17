#!/usr/bin/env bash
#SBATCH --job-name=a5-pd-t0t1
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-correctness-c7eb-20261015-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-correctness-c7eb-20261015-r1/logs/%x-%j.out

set -Eeuo pipefail
RUN_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-correctness-c7eb-20261015-r1
SOURCE_TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/candidate/source
CAND=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/build/candidate/install
REF=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
mkdir -p "$RUN_ROOT/logs" "$RUN_ROOT/results" "$RUN_ROOT/source"
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RUN_ROOT/results/job-exit-code"
    touch "$RUN_ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

cp -a "$SOURCE_TEMPLATE/." "$RUN_ROOT/source/"
SOURCE=$RUN_ROOT/source
mkdir -p "$SOURCE/local-install/lib/ivl"
ln -sfn "$CAND/lib/ivl/uvm_dpi.vpi" "$SOURCE/local-install/lib/ivl/uvm_dpi.vpi"
tar -xzf "$RUN_ROOT/input/test-overlay.tar.gz" -C "$SOURCE"
cp "$RUN_ROOT/input/focused-legacy.list" "$RUN_ROOT/input/focused-json.list" "$RUN_ROOT/input/selection.txt" "$SOURCE/"

verify_hash() {
    expected=$1 path=$2
    actual=$(sha256sum "$path" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "hash mismatch: $path expected=$expected actual=$actual" >&2
        return 1
    fi
}
verify_hash db43d05775ebdbff5dc424cef35a122203326832b46ceaf3bac1745e8d2f1d4f "$SOURCE/vvp/codes.cc"
verify_hash d1cd2eda3ea312af346f99de3043f0d45d6d88ef5e5ddb2841a3411183cc6138 "$SOURCE/vvp/codes.h"
verify_hash 5da4a9503e8aa334aab45603d537b8e431fe7ddaf7779bcc45dc7d67ccd25687 "$SOURCE/vvp/compile.cc"
verify_hash c81cb7f0a0a089f0b70d95b7626468554dcd98a966938ff74563f0ef399424be "$SOURCE/vvp/vthread.cc"
verify_hash 59e1dfed065404f649b2f07fddbd365dfdbffcddf57d468b9c04c38d25722b98 "$CAND/bin/iverilog"
verify_hash 1db5f5ec7f895df9b012983575a764fb69762728f706a92f069784c33abac1e9 "$CAND/bin/vvp"
verify_hash f21a07b9b8c2a92b36d6537f4d3a54e72880d6c2009bdcd4908f3f8774b13fbb "$CAND/bin/iverilog-vpi"
grep -qx "measurement_base=$BASE" /home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/input-manifest.txt

export PATH="$CAND/bin:$PATH"
export IVERILOG="$CAND/bin/iverilog"
export VVP="$CAND/bin/vvp"
export IVPI="$CAND/bin/iverilog-vpi"
export IVERILOG_BIN="$CAND/bin/iverilog"
export VVP_BIN="$CAND/bin/vvp"
export IVERILOG_VPI_BIN="$CAND/bin/iverilog-vpi"
export IVERILOG_VPI="$CAND/bin/iverilog-vpi"
export VPI_MODULE_DIR="$CAND/lib/ivl"
export UVM_DPI="$CAND/lib/ivl/uvm_dpi.vpi"
printf 'measurement_base=%s\n' "$BASE" > "$RUN_ROOT/results/provenance.txt"
sha256sum "$CAND/bin/iverilog" "$CAND/bin/vvp" "$CAND/bin/iverilog-vpi" "$REF/bin/vvp" \
    >> "$RUN_ROOT/results/provenance.txt"
cat "$RUN_ROOT/input/selection.txt" >> "$RUN_ROOT/results/provenance.txt"

status=0
cd "$SOURCE"
if ci/run-smoke.sh > "$RUN_ROOT/logs/smoke.log" 2>&1; then
    echo 'smoke=passed' >> "$RUN_ROOT/results/provenance.txt"
else
    echo 'smoke=failed' >> "$RUN_ROOT/results/provenance.txt"
    tail -n 120 "$RUN_ROOT/logs/smoke.log"
    status=1
fi
cd "$SOURCE/ivtest"
if perl ./vvp_reg.pl "$RUN_ROOT/input/focused-legacy.list" > "$RUN_ROOT/logs/focused-legacy.log" 2>&1; then
    echo 'focused_legacy=passed' >> "$RUN_ROOT/results/provenance.txt"
else
    echo 'focused_legacy=failed' >> "$RUN_ROOT/results/provenance.txt"
    tail -n 120 "$RUN_ROOT/logs/focused-legacy.log"
    status=1
fi
if python3 ./vvp_reg.py "$RUN_ROOT/input/focused-json.list" > "$RUN_ROOT/logs/focused-json.log" 2>&1; then
    echo 'focused_json=passed' >> "$RUN_ROOT/results/provenance.txt"
else
    echo 'focused_json=failed' >> "$RUN_ROOT/results/provenance.txt"
    tail -n 120 "$RUN_ROOT/logs/focused-json.log"
    status=1
fi
cd "$SOURCE"
if benchmarks/sim-hotspots/run.sh --json "$REF/bin/vvp" "$CAND/bin/vvp" 1 \
    > "$RUN_ROOT/logs/benchmark-output.json" 2> "$RUN_ROOT/logs/benchmark-output.stderr"; then
    echo 'sim_hotspots_one_pair_byte_output=passed' >> "$RUN_ROOT/results/provenance.txt"
else
    echo 'sim_hotspots_one_pair_byte_output=failed' >> "$RUN_ROOT/results/provenance.txt"
    tail -n 120 "$RUN_ROOT/logs/benchmark-output.stderr"
    status=1
fi
printf 'status=%s\n' "$status" >> "$RUN_ROOT/results/provenance.txt"
exit "$status"
