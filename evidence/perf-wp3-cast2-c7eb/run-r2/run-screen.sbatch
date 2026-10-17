#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp3-cast2-r2
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
UVM_CORE=78c06547a2a0a29b3dc9dcafae62b75b2ff61544
INPUT="$RUN_DIR/incoming"
RESULTS="$RUN_DIR/results"
OLD_TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools

mkdir -p "$RUN_DIR/logs" "$RUN_DIR/build" "$RUN_DIR/tools/debs" \
  "$RUN_DIR/tools/root" "$RUN_DIR/wrappers" "$RESULTS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

cd "$INPUT"
cp "$INPUT/input-manifest.txt" "$RUN_DIR/input-manifest.txt"
grep -qx "measurement_base=$BASE" "$INPUT/input-manifest.txt"
grep -qx "uvm_core=$UVM_CORE" "$INPUT/input-manifest.txt"
ref_sha=$(awk '$2 ~ /reference-source.tar.gz$/ {print $1}' "$INPUT/input-manifest.txt")
cand_sha=$(awk '$2 ~ /candidate-source.tar.gz$/ {print $1}' "$INPUT/input-manifest.txt")
printf '%s  %s\n%s  %s\n' \
  "$ref_sha" reference-source.tar.gz "$cand_sha" candidate-source.tar.gz \
  | sha256sum -c -
mkdir -p "$INPUT/reference/source" "$INPUT/candidate/source"
tar -xzf reference-source.tar.gz -C "$INPUT/reference/source"
tar -xzf candidate-source.tar.gz -C "$INPUT/candidate/source"
REF_SRC="$INPUT/reference/source"
CAND_SRC="$INPUT/candidate/source"

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
  local side=$1 src prefix
  src="$INPUT/$side/source"
  prefix="$RUN_DIR/build/$side/install"
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

REF_VVP="$RUN_DIR/build/reference/install/bin/vvp"
CAND_VVP="$RUN_DIR/build/candidate/install/bin/vvp"
IVERILOG="$RUN_DIR/build/reference/install/bin/iverilog"
IVERILOG_VPI="$RUN_DIR/build/reference/install/bin/iverilog-vpi"
UVM_DPI=$(find "$RUN_DIR/build/reference/install" -type f -name uvm_dpi.vpi -print -quit)
for exe in "$REF_VVP" "$CAND_VVP" "$IVERILOG" "$IVERILOG_VPI"; do test -x "$exe"; done
test -n "$UVM_DPI" && test -s "$UVM_DPI"

for side in reference candidate; do
  install="$RUN_DIR/build/$side/install"
  src="$INPUT/$side/source"
  "$install/bin/iverilog" -g2005-sv -o "$RESULTS/cast-$side.vvp" \
    "$src/ivtest/ivltests/sv_cast2_4state.v"
  "$install/bin/vvp" "$RESULTS/cast-$side.vvp" > "$RESULTS/cast-$side.out"
  "$install/bin/iverilog" -g2005-sv -tvvp -o "$RESULTS/cast-$side.il" \
    "$src/ivtest/ivltests/sv_cast2_4state.v"
  grep -q '%cast2;' "$RESULTS/cast-$side.il"
done
cmp "$RESULTS/cast-reference.out" "$RESULTS/cast-candidate.out"

RUNNER="$REF_SRC/benchmarks/sim-hotspots/run_json_callgrind.py"
python3 - "$REF_SRC/benchmarks/sim-hotspots/run_json.py" "$RUNNER" <<'PY'
from pathlib import Path
import sys

source, destination = map(Path, sys.argv[1:])
text = source.read_text()
if text.count("COMMAND_TIMEOUT_SECONDS = 60") != 1:
    raise SystemExit("unexpected benchmark runner timeout declaration")
text = text.replace("COMMAND_TIMEOUT_SECONDS = 60", "COMMAND_TIMEOUT_SECONDS = 1200", 1)
start = text.index("def perf_command():")
end = text.index("def parse_rss(", start)
text = text[:start] + "def perf_command():\n    return None\n\n\n" + text[end:]
destination.write_text(text)
PY

CALLGRIND_DIR="$RESULTS/callgrind"
mkdir -p "$CALLGRIND_DIR"
make_wrapper() {
  local side=$1 runtime=$2 path="$RUN_DIR/wrappers/callgrind-$1"
  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
exec "$VALGRIND" --quiet --tool=callgrind \\
  --callgrind-out-file="$CALLGRIND_DIR/\$name.callgrind" \\
  --log-file="$CALLGRIND_DIR/\$name.valgrind.log" "$runtime" "\$@"
EOF
  chmod +x "$path"
}
make_wrapper reference "$REF_VVP"
make_wrapper candidate "$CAND_VVP"
set +e
PATH="$RUN_DIR/build/reference/install/bin:$PATH" \
  IVERILOG="$IVERILOG" IVERILOG_VPI="$IVERILOG_VPI" UVM_DPI="$UVM_DPI" \
  python3 "$RUNNER" "$RUN_DIR/wrappers/callgrind-reference" \
    "$RUN_DIR/wrappers/callgrind-candidate" 1 > "$RESULTS/sim-hotspots.json"
runner_exit=$?
set -e
printf 'run_json_exit=%s\nmeasurement_base=%s\nuvm_core=%s\n' \
  "$runner_exit" "$BASE" "$UVM_CORE" > "$RESULTS/run-json-exit.txt"

python3 - "$RESULTS/sim-hotspots.json" "$CALLGRIND_DIR" \
  "$RESULTS/instruction-counts.csv" "$RESULTS/screen-status.txt" <<'PY'
import csv
import json
import sys
from pathlib import Path

result_path, profile_dir, csv_path, status_path = map(Path, sys.argv[1:])
data = json.loads(result_path.read_text())
rows = []
outputs_identical = len(data["benchmarks"]) == 18

def instructions(path):
    summaries = [line.split()[1] for line in path.read_text().splitlines()
                 if line.startswith("summary:")]
    if len(summaries) != 1:
        raise RuntimeError(f"expected one Callgrind summary in {path}")
    return int(summaries[0])

for name, item in data["benchmarks"].items():
    identical = item.get("status") == "ok" and item.get("identical_all_runs") is True
    outputs_identical &= identical
    ref = instructions(profile_dir / f"{name}-01-reference.callgrind")
    cand = instructions(profile_dir / f"{name}-01-candidate.callgrind")
    delta_pct = (cand - ref) * 100.0 / ref
    rows.append((name, ref, cand, cand - ref, f"{delta_pct:.6f}", "yes" if identical else "no"))

with csv_path.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("benchmark", "reference_ir", "candidate_ir", "delta_ir", "delta_pct", "output_identical"))
    writer.writerows(rows)

by_name = {row[0]: row for row in rows}
improvement = -float(by_name["behav"][4]) if "behav" in by_name else 0.0
regressions = [float(row[4]) for row in rows if row[0] != "behav"]
largest_regression = max(regressions, default=0.0)
qualifies = outputs_identical and improvement >= 10.0 and largest_regression <= 2.0
status_path.write_text(
    f"measurement_base={data.get('measurement_base', 'c7ebca768c21c251d9c165c9aff0e363768030b1')}\n"
    "target=behav\n"
    f"target_instruction_improvement_pct={improvement:.6f}\n"
    f"largest_other_instruction_regression_pct={largest_regression:.6f}\n"
    f"all_outputs_identical={'yes' if outputs_identical else 'no'}\n"
    f"qualifies={'yes' if qualifies else 'no'}\n"
)
PY
test "$runner_exit" -eq 0

{
  uname -a
  g++ --version | sed -n '1p'
  "$REF_VVP" -V 2>&1 | sed -n '1,4p'
  "$CAND_VVP" -V 2>&1 | sed -n '1,4p'
  "$VALGRIND" --version
} > "$RUN_DIR/environment.txt"
find "$RESULTS" -type f ! -name results.SHA256SUMS -print0 \
  | sort -z | xargs -0 sha256sum > "$RESULTS/results.SHA256SUMS"
