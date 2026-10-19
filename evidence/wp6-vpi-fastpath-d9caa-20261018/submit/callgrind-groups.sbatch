#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-d9caa-cg
#SBATCH --partition=verilog
#SBATCH --array=0-3%2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2/logs/%x-%A_%a.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
BASE=d9caaaea5b410ed14e7ca14be828fc2f2c9fea44
REF_INSTALL=/home/dsell/toolchains/iverilog-uvm-d9caaaea5b410ed14e7ca14be828fc2f2c9fea44-a5-wp6-r2
CAND_INSTALL=$ROOT/install/candidate
INPUT=$ROOT/input
case "${SLURM_ARRAY_TASK_ID:?}" in
  0) GROUP=core; BENCHMARKS=(rtl_pipe randomize_dv_txn uvm_traffic multi_clock io_text fork_heavy) ;;
  1) GROUP=vectors; BENCHMARKS=(vpi_callbacks classq gate_strength large_memory wide_vectors uvm_config_factory) ;;
  2) GROUP=mixed; BENCHMARKS=(rtl_alu behav strings_aa_queue randomize_z3 waveform_vcd) ;;
  3) GROUP=fst ;;
  *) exit 2 ;;
esac
RESULTS=$ROOT/callgrind/$GROUP
SOURCE=$ROOT/source/callgrind-$GROUP
PROFILES=$RESULTS/callgrind
mkdir -p "$RESULTS" "$ROOT/logs" "$(dirname "$SOURCE")"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test -f "$ROOT/build/BUILD_SUCCESS"
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
(
  cd "$INPUT"
  sha256sum --check source-inputs.sha256
)
mkdir -p "$SOURCE/third_party/uvm/2020.2.0" "$SOURCE/third_party/uvm/2020.3.0" "$SOURCE/uvm-core"
tar -xzf "$INPUT/iverilog-uvm-d9caa-sourceonly.tar.gz" -C "$SOURCE"
tar -xzf "$INPUT/uvm-2020.2.0.tar.gz" -C "$SOURCE/third_party/uvm/2020.2.0"
tar -xzf "$INPUT/uvm-2020.3.0.tar.gz" -C "$SOURCE/third_party/uvm/2020.3.0"
tar -xzf "$INPUT/uvm-core-78c0654.tar.gz" -C "$SOURCE/uvm-core"
patch --dry-run -p1 -d "$SOURCE" < "$INPUT/candidate.patch" > "$RESULTS/patch-check.log"
patch -p1 -d "$SOURCE" < "$INPUT/candidate.patch" > "$RESULTS/patch.log"
mkdir -p "$PROFILES"
printf 'measurement_base=%s\ngroup=%s\n' "$BASE" "$GROUP" > "$RESULTS/provenance.txt"
cat "$INPUT/source-provenance.txt" >> "$RESULTS/provenance.txt"
sha256sum "$INPUT/candidate.patch" "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" > "$RESULTS/provenance.sha256"

if [[ "$GROUP" == fst ]]; then
  PROGRAM=$RESULTS/waveform_fst.vvp
  "$REF_INSTALL/bin/iverilog" -g2012 -o "$PROGRAM" "$SOURCE/benchmarks/sim-hotspots/waveform.sv"
  for side in reference candidate; do
    runtime=$REF_INSTALL/bin/vvp
    [[ "$side" == candidate ]] && runtime=$CAND_INSTALL/bin/vvp
    set +e
    (cd "$RESULTS" && /usr/bin/valgrind --quiet --tool=callgrind --fair-sched=yes \
      --callgrind-out-file="$PROFILES/waveform_fst-01-$side.callgrind" \
      --log-file="$PROFILES/waveform_fst-01-$side.valgrind.log" \
      "$runtime" -n "$PROGRAM" +use_fst -fst -no-date > "$RESULTS/$side.stdout" 2>&1)
    rc=$?
    set -e
    printf '%s\n' "$rc" > "$RESULTS/$side.exit-code"
    test -s "$PROFILES/waveform_fst-01-$side.callgrind"
  done
  python3 - "$BASE" "$PROFILES" "$RESULTS/instruction-counts.csv" <<'PY'
import csv, sys
from pathlib import Path
base, profiles, output = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
counts = []
for side in ("reference", "candidate"):
    path = profiles / f"waveform_fst-01-{side}.callgrind"
    values = [line.split()[1] for line in path.read_text().splitlines() if line.startswith("summary:")]
    if len(values) != 1:
        raise SystemExit(f"expected one Callgrind summary in {path}")
    counts.append(int(values[0]))
reference, candidate = counts
with output.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "benchmark", "reference_ir", "candidate_ir", "delta_ir", "delta_pct", "output_identical"))
    writer.writerow((base, "waveform_fst", reference, candidate, candidate-reference,
                     f"{(candidate-reference)*100.0/reference:.6f}", "checked_by_final_wall"))
PY
else
  RUNNER=$SOURCE/benchmarks/sim-hotspots/run_json_callgrind-m3-$GROUP.py
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
    cat > "$path" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
args=(--quiet --tool=callgrind)
exec /usr/bin/valgrind "\${args[@]}" --callgrind-out-file="$PROFILES/\$name.callgrind" \\
  --log-file="$PROFILES/\$name.valgrind.log" "$runtime" "\$@"
WRAPPER
    chmod +x "$path"
  }
  make_wrapper reference "$REF_INSTALL/bin/vvp"
  make_wrapper candidate "$CAND_INSTALL/bin/vvp"
  export VALGRIND_LIB=/usr/libexec/valgrind
  export IVERILOG=$CAND_INSTALL/bin/iverilog IVERILOG_VPI=$CAND_INSTALL/bin/iverilog-vpi
  export UVM_DPI=$REF_INSTALL/lib/ivl/uvm_dpi.vpi
  printf 'measurement_base=%s\ngroup=%s\nbenchmarks=%s\n' "$BASE" "$GROUP" "${BENCHMARKS[*]}" > "$RESULTS/provenance.txt"
  sha256sum "$RUNNER" "$INPUT/candidate.patch" "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" > "$RESULTS/provenance.sha256"
  python3 "$RUNNER" "$RESULTS/callgrind-reference" "$RESULTS/callgrind-candidate" 1 > "$RESULTS/corpus.json"
  python3 - "$GROUP" "$BASE" "$RESULTS/corpus.json" "$PROFILES" "$RESULTS/instruction-counts.csv" <<'PY'
import csv, json, sys
from pathlib import Path
group, base = sys.argv[1], sys.argv[2]
corpus, profiles, output = Path(sys.argv[3]), Path(sys.argv[4]), Path(sys.argv[5])
data = json.loads(corpus.read_text())
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"{name}: status/output mismatch in JSON runner")
    counts = []
    for side in ("reference", "candidate"):
        path = profiles / f"{name}-01-{side}.callgrind"
        values = [line.split()[1] for line in path.read_text().splitlines() if line.startswith("summary:")]
        if len(values) != 1:
            raise SystemExit(f"expected one Callgrind summary in {path}")
        counts.append(int(values[0]))
    reference, candidate = counts
    rows.append((name, reference, candidate, candidate-reference,
                 f"{(candidate-reference)*100.0/reference:.6f}", "yes"))
expected = {"core": 6, "vectors": 6, "mixed": 5}[group]
if len(rows) != expected:
    raise SystemExit(f"{group}: expected {expected} profiles, found {len(rows)}")
with output.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "benchmark", "reference_ir", "candidate_ir", "delta_ir", "delta_pct", "output_identical"))
    for row in rows:
        writer.writerow((base, *row))
PY
fi

sha256sum "$RESULTS/instruction-counts.csv" "$RESULTS/provenance.txt" \
  "$RESULTS/provenance.sha256" > "$RESULTS/SHA256SUMS"
tar -czf "$RESULTS/callgrind-$GROUP.tgz" -C "$RESULTS" callgrind
rm -rf "$PROFILES"
touch "$RESULTS/SUCCESS"
