#!/usr/bin/env bash
#SBATCH --job-name=a5-conv-374b-cg-r2
#SBATCH --partition=verilog
#SBATCH --array=0-3%3
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r2/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r2/logs/%x-%A_%a.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r2
BASE=374b037e7c8fba7097e0b86b05be7956ca6b5487
INPUT=$ROOT/input
SOURCE=$ROOT/source/candidate
REF_INSTALL=$ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools/root
VALGRIND=$TOOLS/usr/bin/valgrind
WORKLOADS=$SOURCE/benchmarks/sim-hotspots

case "${SLURM_ARRAY_TASK_ID:?}" in
    0) GROUP=core; BENCHMARKS=(rtl_pipe randomize_dv_txn uvm_traffic multi_clock io_text fork_heavy) ;;
    1) GROUP=vectors; BENCHMARKS=(vpi_callbacks classq gate_strength large_memory wide_vectors uvm_config_factory) ;;
    2) GROUP=mixed; BENCHMARKS=(rtl_alu behav strings_aa_queue randomize_z3 waveform_vcd) ;;
    3) GROUP=fst; BENCHMARKS=(waveform_fst) ;;
    *) echo "bad array task id: $SLURM_ARRAY_TASK_ID" >&2; exit 2 ;;
esac

RESULTS=$ROOT/corpus-screen/$GROUP
PROFILES=$RESULTS/callgrind
RUNNER=$WORKLOADS/run_json_callgrind-$GROUP.py
mkdir -p "$RESULTS" "$PROFILES" "$ROOT/logs"
finish() {
    local rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C "$ROOT/source/reference" rev-parse HEAD)" = "$BASE"
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
test -x "$CAND_INSTALL/bin/iverilog" && test -x "$CAND_INSTALL/bin/iverilog-vpi"
test -x "$VALGRIND" && test -f "$INPUT/run_json_callgrind.py"
export VALGRIND_LIB=$TOOLS/usr/libexec/valgrind
export PATH="$(dirname "$CAND_INSTALL/bin/iverilog"):$PATH"
export IVERILOG=$CAND_INSTALL/bin/iverilog
export IVERILOG_VPI=$CAND_INSTALL/bin/iverilog-vpi
export UVM_DPI=$REF_INSTALL/lib/ivl/uvm_dpi.vpi
test -s "$UVM_DPI"

cp "$INPUT/run_json_callgrind.py" "$RUNNER"
python3 - "$RUNNER" "${BENCHMARKS[@]}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
names = sys.argv[2:]
text = path.read_text()
start = text.index("BENCHMARKS = (")
end = text.index("\n)", start) + 2
block = "BENCHMARKS = (\n" + "".join(f'    "{name}",\n' for name in names) + ")"
path.write_text(text[:start] + block + text[end:])
PY

make_wrapper() {
    local side=$1 runtime=$2 path=$RESULTS/callgrind-$1
    cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
args=(--quiet --tool=callgrind)
if [[ "\$name" == waveform_fst-* ]]; then args+=(--fair-sched=yes); fi
exec "$VALGRIND" "\${args[@]}" \\
  --callgrind-out-file="$PROFILES/\$name.callgrind" \\
  --log-file="$PROFILES/\$name.valgrind.log" \\
  "$runtime" "\$@"
EOF
    chmod +x "$path"
}
make_wrapper reference "$REF_INSTALL/bin/vvp"
make_wrapper candidate "$CAND_INSTALL/bin/vvp"

printf 'measurement_base=%s\ngroup=%s\nbenchmarks=%s\n' \
    "$BASE" "$GROUP" "${BENCHMARKS[*]}" > "$RESULTS/provenance.txt"
sha256sum "$RUNNER" "$INPUT/run_json_callgrind.py" \
    "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" \
    "$REF_INSTALL/bin/iverilog" "$CAND_INSTALL/bin/iverilog" \
    > "$RESULTS/provenance.sha256"

python3 "$RUNNER" "$RESULTS/callgrind-reference" "$RESULTS/callgrind-candidate" 1 \
    > "$RESULTS/corpus.json"

python3 - "$GROUP" "$RESULTS/corpus.json" "$PROFILES" "$RESULTS/instruction-counts.csv" <<'PY'
import csv
import json
import sys
from pathlib import Path

group, corpus_path, profile_dir, csv_path = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4])
data = json.loads(corpus_path.read_text())
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"{name}: status/output mismatch in JSON runner")
    counts = []
    for side in ("reference", "candidate"):
        path = profile_dir / f"{name}-01-{side}.callgrind"
        summaries = [line.split()[1] for line in path.read_text().splitlines()
                     if line.startswith("summary:")]
        if len(summaries) != 1:
            raise SystemExit(f"expected one Callgrind summary in {path}")
        counts.append(int(summaries[0]))
    reference, candidate = counts
    rows.append((name, reference, candidate, candidate - reference,
                 f"{(candidate-reference)*100.0/reference:.6f}", "yes"))

expected = {"core": 6, "vectors": 6, "mixed": 5, "fst": 1}[group]
if len(rows) != expected:
    raise SystemExit(f"{group}: expected {expected} profiles, found {len(rows)}")
with csv_path.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "benchmark", "reference_ir", "candidate_ir",
                     "delta_ir", "delta_pct", "output_identical"))
    for name, reference, candidate, delta, pct, identical in rows:
        writer.writerow(("374b037e7c8fba7097e0b86b05be7956ca6b5487", name,
                         reference, candidate, delta, pct, identical))
PY

sha256sum "$RESULTS/corpus.json" "$RESULTS/instruction-counts.csv" \
    "$RESULTS/provenance.txt" "$RESULTS/provenance.sha256" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
