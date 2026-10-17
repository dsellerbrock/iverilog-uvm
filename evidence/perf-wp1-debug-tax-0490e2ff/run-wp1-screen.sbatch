#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp1-screen-r3
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3
INPUT="$RUN_DIR/input"
RESULTS="$RUN_DIR/results"
REF_SRC="$INPUT/reference/source"
CAND_SRC="$INPUT/candidate/source"
REF_INSTALL="$RUN_DIR/build/reference/install"
CAND_INSTALL="$RUN_DIR/build/candidate/install"
OLD_TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-1174ea06-7f35-20261014-r1/tools

mkdir -p "$RUN_DIR/logs" "$RUN_DIR/build" "$RUN_DIR/tools/debs" "$RUN_DIR/tools/root" \
  "$RUN_DIR/wrappers" "$RESULTS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

cd "$RUN_DIR/incoming"
printf '%s  %s\n' \
  046ac269ed5fe0f0414c2d782cf5722ed1d638e2b775d9d0726748099f6115ea reference.tar.gz \
  4b7c6bb4c36bbb3a88efd97e64d3bc0ab1b4ed09156341e95d9293a28f33193d candidate.tar.gz \
  | sha256sum -c -
mkdir -p "$INPUT/reference" "$INPUT/candidate"
tar -xzf reference.tar.gz -C "$INPUT/reference"
tar -xzf candidate.tar.gz -C "$INPUT/candidate"

cp "$OLD_TOOLS/debs/valgrind_1%3a3.26.0-0ubuntu1_amd64.deb" \
  "$OLD_TOOLS/debs/libc6-dbg_2.43-2ubuntu2.4_amd64.deb" "$RUN_DIR/tools/debs/"
cat > "$RUN_DIR/tools/packages.SHA256SUMS" <<'EOF'
523851368691971a1553c7dacc7cf9e0cd54a78ca70bbdd735d932f16e089ae3  libc6-dbg_2.43-2ubuntu2.4_amd64.deb
70b10c31307700a388262baa9cff7a3b27814a9716b6f19e8f748a56bcbfa442  valgrind_1%3a3.26.0-0ubuntu1_amd64.deb
EOF
(cd "$RUN_DIR/tools/debs" && sha256sum -c "$RUN_DIR/tools/packages.SHA256SUMS")
dpkg-deb -x "$RUN_DIR/tools/debs/valgrind_1%3a3.26.0-0ubuntu1_amd64.deb" "$RUN_DIR/tools/root"
dpkg-deb -x "$RUN_DIR/tools/debs/libc6-dbg_2.43-2ubuntu2.4_amd64.deb" "$RUN_DIR/tools/root"
VALGRIND="$RUN_DIR/tools/root/usr/bin/valgrind"
export VALGRIND_LIB="$RUN_DIR/tools/root/usr/libexec/valgrind"
"$VALGRIND" --version > "$RUN_DIR/tools/valgrind-version.txt"

build_tree() {
  local side=$1 src="$INPUT/$1/source" prefix="$RUN_DIR/build/$1/install"
  mkdir -p "$RUN_DIR/build/$side"
  (
    cd "$src"
    sh autoconf.sh > "$RUN_DIR/logs/autoconf-$side.log" 2>&1
    ./configure --prefix="$prefix" --enable-libveriuser CFLAGS='-g0 -O2' CXXFLAGS='-g0 -O2' \
      > "$RUN_DIR/logs/configure-$side.log" 2>&1
    make -j4 > "$RUN_DIR/logs/build-$side.log" 2>&1
    make install > "$RUN_DIR/logs/install-$side.log" 2>&1
  )
}
build_tree reference
build_tree candidate

REF_VVP="$REF_INSTALL/bin/vvp"
CAND_VVP="$CAND_INSTALL/bin/vvp"
IVERILOG="$REF_INSTALL/bin/iverilog"
IVERILOG_VPI="$REF_INSTALL/bin/iverilog-vpi"
for exe in "$REF_VVP" "$CAND_VVP" "$IVERILOG" "$IVERILOG_VPI"; do
  test -x "$exe"
done
UVM_DPI=$(find "$REF_INSTALL" -type f -name uvm_dpi.vpi -print -quit)
test -n "$UVM_DPI" && test -s "$UVM_DPI"

printf 'campaign_pinned_base=%s\nmeasurement_base=%s\nreference_archive_sha256=%s\ncandidate_archive_sha256=%s\nuvm_core_submodule=%s\n' \
  0490e2ff48f3169283e7d71afe2a16424e2cf3aa \
  0490e2ff48f3169283e7d71afe2a16424e2cf3aa \
  046ac269ed5fe0f0414c2d782cf5722ed1d638e2b775d9d0726748099f6115ea \
  4b7c6bb4c36bbb3a88efd97e64d3bc0ab1b4ed09156341e95d9293a28f33193d \
  78c06547a2a0a29b3dc9dcafae62b75b2ff61544 > "$RUN_DIR/source-manifest.txt"
{
  uname -a
  g++ --version > "$RUN_DIR/gxx-version.txt"
  sed -n '1p' "$RUN_DIR/gxx-version.txt"
  "$REF_VVP" -V > "$RUN_DIR/reference-vvp-version.txt" 2>&1
  sed -n '1,4p' "$RUN_DIR/reference-vvp-version.txt"
  "$CAND_VVP" -V > "$RUN_DIR/candidate-vvp-version.txt" 2>&1
  sed -n '1,4p' "$RUN_DIR/candidate-vvp-version.txt"
  "$VALGRIND" --version
} > "$RUN_DIR/environment.txt"

make_vvp_wrapper() {
  local side=$1
  mkdir -p "$RUN_DIR/wrappers/$side"
  cat > "$RUN_DIR/wrappers/$side/vvp" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$RUN_DIR/build/$side/install/bin/vvp" "\$@"
EOF
  chmod +x "$RUN_DIR/wrappers/$side/vvp"
}
make_vvp_wrapper reference
make_vvp_wrapper candidate

run_focus_pair() {
  local name=$1 script=$2 side runtime status
  for side in reference candidate; do
    runtime="$REF_VVP"
    [ "$side" = reference ] || runtime="$CAND_VVP"
    status="$RESULTS/focus-$name-$side.txt"
    if [ "$name" = region-trace ]; then
      PATH="$RUN_DIR/wrappers/$side:$REF_INSTALL/bin:$PATH" \
        timeout --signal=TERM --kill-after=10s 1200s bash "$CAND_SRC/$script" > "$status" 2>&1
    else
      PATH="$REF_INSTALL/bin:$PATH" IVERILOG="$IVERILOG" VVP="$runtime" \
        timeout --signal=TERM --kill-after=10s 1200s bash "$CAND_SRC/$script" > "$status" 2>&1
    fi
  done
  cmp "$RESULTS/focus-$name-reference.txt" "$RESULTS/focus-$name-candidate.txt"
}
run_focus_pair context-stats tests/vvp_runtime/run_process_kill_call_context.sh
run_focus_pair region-trace tests/m6_region_trace/run_region_trace.sh
run_focus_pair coverage-report tests/vvp_runtime/run_covgrp_options_report.sh

RUNNER="$REF_SRC/benchmarks/sim-hotspots/run_json_callgrind.py"
python3 - "$REF_SRC/benchmarks/sim-hotspots/run_json.py" "$RUNNER" <<'PY'
from pathlib import Path
import sys

source, destination = map(Path, sys.argv[1:])
text = source.read_text()
text = text.replace("COMMAND_TIMEOUT_SECONDS = 60", "COMMAND_TIMEOUT_SECONDS = 1200", 1)
start = text.index("def perf_command():")
end = text.index("def parse_rss(", start)
text = text[:start] + "def perf_command():\n    return None\n\n\n" + text[end:]
destination.write_text(text)
PY
CALLGRIND_DIR="$RESULTS/callgrind"
mkdir -p "$CALLGRIND_DIR"
make_callgrind_wrapper() {
  local side=$1 real_vvp=$2 path="$RUN_DIR/wrappers/callgrind-$1"
  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
exec "$VALGRIND" --quiet --tool=callgrind \\
  --callgrind-out-file="$CALLGRIND_DIR/\$name.callgrind" \\
  --log-file="$CALLGRIND_DIR/\$name.valgrind.log" "$real_vvp" "\$@"
EOF
  chmod +x "$path"
}
make_callgrind_wrapper reference "$REF_VVP"
make_callgrind_wrapper candidate "$CAND_VVP"
set +e
PATH="$REF_INSTALL/bin:$PATH" IVERILOG="$IVERILOG" IVERILOG_VPI="$IVERILOG_VPI" \
  UVM_DPI="$UVM_DPI" CALLGRIND_DIR="$CALLGRIND_DIR" \
  python3 "$RUNNER" "$RUN_DIR/wrappers/callgrind-reference" \
    "$RUN_DIR/wrappers/callgrind-candidate" 1 > "$RESULTS/sim-hotspots.json"
runner_exit=$?
set -e
printf 'run_json_exit=%s\n' "$runner_exit" > "$RESULTS/run-json-exit.txt"
test "$runner_exit" -eq 0

python3 - "$RESULTS/sim-hotspots.json" "$CALLGRIND_DIR" "$RESULTS/instruction-counts.csv" "$RESULTS/screen-status.txt" <<'PY'
import csv
import json
import sys
from pathlib import Path

result_path, profile_dir, csv_path, status_path = map(Path, sys.argv[1:])
data = json.loads(result_path.read_text())
names = list(data["benchmarks"])
rows = []
all_outputs_identical = True

def instructions(path):
    summaries = [line.split()[1] for line in path.read_text().splitlines()
                 if line.startswith("summary:")]
    if len(summaries) != 1:
        raise RuntimeError(f"expected one Callgrind summary in {path}")
    return int(summaries[0])

for name in names:
    benchmark = data["benchmarks"][name]
    ok = benchmark.get("status") == "ok" and benchmark.get("identical_all_runs") is True
    all_outputs_identical &= ok
    ref = instructions(profile_dir / f"{name}-01-reference.callgrind")
    cand = instructions(profile_dir / f"{name}-01-candidate.callgrind")
    delta_pct = (cand - ref) * 100.0 / ref
    rows.append((name, ref, cand, cand - ref, f"{delta_pct:.6f}", "yes" if ok else "no"))

with csv_path.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("benchmark", "reference_ir", "candidate_ir", "delta_ir", "delta_pct", "output_identical"))
    writer.writerows(rows)

by_name = {row[0]: row for row in rows}
target_improvement_pct = -float(by_name["behav"][4])
other_regressions = [float(row[4]) for row in rows if row[0] != "behav"]
largest_other_regression = max(other_regressions, default=0.0)
qualifies = all_outputs_identical and target_improvement_pct >= 10.0 and largest_other_regression <= 2.0
status_path.write_text(
    "campaign_pinned_base=0490e2ff48f3169283e7d71afe2a16424e2cf3aa\n"
    "measurement_base=0490e2ff48f3169283e7d71afe2a16424e2cf3aa\n"
    "target=behav\n"
    f"target_instruction_improvement_pct={target_improvement_pct:.6f}\n"
    f"largest_other_instruction_regression_pct={largest_other_regression:.6f}\n"
    f"all_outputs_identical={'yes' if all_outputs_identical else 'no'}\n"
    f"qualifies={'yes' if qualifies else 'no'}\n"
)
PY

find "$RESULTS" -type f -print0 | sort -z | xargs -0 sha256sum > "$RUN_DIR/results.SHA256SUMS"
sha256sum "$RUN_DIR/source-manifest.txt" "$RUN_DIR/environment.txt" \
  "$RUNNER" >> "$RUN_DIR/results.SHA256SUMS"
