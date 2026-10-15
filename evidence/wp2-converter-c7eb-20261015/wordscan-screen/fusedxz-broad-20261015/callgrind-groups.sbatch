#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp2-fusedxz-cg
#SBATCH --array=0-2%3
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-broad-20261015/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-broad-20261015/logs/%A_%a.out

set -Eeuo pipefail
PARENT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-broad-20261015
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
REF_INSTALL=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install
CAND_INSTALL=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-20261015-r1/build/candidate/install
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools/root
case "${SLURM_ARRAY_TASK_ID:?}" in
  0) GROUP=core ;;
  1) GROUP=vectors ;;
  2) GROUP=mixed ;;
  *) echo "bad array index: $SLURM_ARRAY_TASK_ID" >&2; exit 2 ;;
esac
ROOT=$PARENT/$GROUP
SOURCE=$ROOT/source
RESULTS=$ROOT/results
WORKLOADS=$SOURCE/benchmarks/sim-hotspots
RUNNER=$WORKLOADS/run_json_callgrind.py
mkdir -p "$RESULTS/callgrind" "$ROOT/logs" "$ROOT/programs" "$ROOT/fst" "$ROOT/wrappers"
finish() { local rc=$?; trap - EXIT; printf '%s\n' "$rc" > "$RESULTS/job-exit-code"; touch "$RESULTS/DONE"; exit "$rc"; }
trap finish EXIT
export VALGRIND_LIB="$TOOLS/usr/libexec/valgrind"
VALGRIND="$TOOLS/usr/bin/valgrind"
ANNOTATE="$TOOLS/usr/bin/callgrind_annotate"
export IVERILOG="$CAND_INSTALL/bin/iverilog"
export IVERILOG_VPI="$CAND_INSTALL/bin/iverilog-vpi"
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
test -x "$IVERILOG" && test -x "$IVERILOG_VPI" && test -f "$RUNNER"
test -f "$SOURCE/local-install/lib/ivl/uvm_dpi.vpi"
printf 'measurement_base=%s\ngroup=%s\nreference_vvp=%s\ncandidate_vvp=%s\n' \
  "$BASE" "$GROUP" "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" > "$RESULTS/provenance.txt"
sha256sum "$PARENT/input/candidate.patch" "$PARENT/input/wordscan-baseline.patch" \
  "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" "$RUNNER" > "$RESULTS/provenance-hashes.txt"
find "$WORKLOADS" -maxdepth 1 -type f \( -name '*.sv' -o -name '*.c' \) -print0 | sort -z | xargs -0 sha256sum >> "$RESULTS/provenance-hashes.txt"
cat > "$ROOT/wrappers/callgrind-reference" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
exec "$VALGRIND" --quiet --tool=callgrind \
  --callgrind-out-file="$RESULTS/callgrind/\$name.callgrind" \
  --log-file="$RESULTS/callgrind/\$name.valgrind.log" \
  "$REF_INSTALL/bin/vvp" "\$@"
WRAP
cat > "$ROOT/wrappers/callgrind-candidate" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
exec "$VALGRIND" --quiet --tool=callgrind \
  --callgrind-out-file="$RESULTS/callgrind/\$name.callgrind" \
  --log-file="$RESULTS/callgrind/\$name.valgrind.log" \
  "$CAND_INSTALL/bin/vvp" "\$@"
WRAP
chmod +x "$ROOT/wrappers/callgrind-reference" "$ROOT/wrappers/callgrind-candidate"
python3 "$RUNNER" "$ROOT/wrappers/callgrind-reference" "$ROOT/wrappers/callgrind-candidate" 1 \
  > "$RESULTS/corpus.json"
python3 - "$RESULTS/corpus.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
bad = [name for name, row in data["benchmarks"].items()
       if row.get("status") != "ok" or not row.get("identical_all_runs")]
if bad:
    raise SystemExit("workload output/status failed: " + ", ".join(bad))
PY
if [ "$GROUP" = mixed ]; then
  "$IVERILOG" -g2012 -o "$ROOT/programs/waveform.vvp" "$WORKLOADS/waveform.sv" \
    > "$ROOT/programs/waveform.compile.log" 2>&1
  for side in reference candidate; do
    mkdir -p "$ROOT/fst/$side"
    if [ "$side" = reference ]; then
      VVP=$REF_INSTALL/bin/vvp
    else
      VVP=$CAND_INSTALL/bin/vvp
    fi
    (
      cd "$ROOT/fst/$side"
      timeout --signal=TERM --kill-after=15s 1200s "$VALGRIND" --quiet --tool=callgrind --fair-sched=yes \
        --callgrind-out-file="$RESULTS/callgrind/waveform_fst-$side.callgrind" \
        --log-file="$RESULTS/callgrind/waveform_fst-$side.valgrind.log" \
        "$VVP" -n +use_fst -fst -no-date "$ROOT/programs/waveform.vvp" \
        > "$RESULTS/waveform_fst-$side.out" 2> "$RESULTS/waveform_fst-$side.err"
    )
  done
  cmp "$RESULTS/waveform_fst-reference.out" "$RESULTS/waveform_fst-candidate.out"
  cmp "$RESULTS/waveform_fst-reference.err" "$RESULTS/waveform_fst-candidate.err"
  diff -r "$ROOT/fst/reference" "$ROOT/fst/candidate"
  test -n "$(find "$ROOT/fst/reference" -type f -print -quit)"
fi
python3 - "$GROUP" "$RESULTS/corpus.json" "$RESULTS/callgrind" "$RESULTS/instruction-counts.csv" <<'PY'
import csv, json, sys
from pathlib import Path
group, corpus_path, profile_dir, output = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4])
corpus = json.loads(corpus_path.read_text())
rows = {}
for path in profile_dir.glob("*.callgrind"):
    stem = path.stem
    if stem.startswith("waveform_fst-"):
        name, side = "waveform_fst", stem.removeprefix("waveform_fst-")
        identical = True
    else:
        side = ""
        name = ""
        for suffix in ("-01-reference", "-01-candidate"):
            if stem.endswith(suffix):
                name = stem[:-len(suffix)]
                side = suffix.rsplit("-", 1)[1]
                break
        if not name or side not in ("reference", "candidate"):
            raise SystemExit(f"unrecognized profile name: {path.name}")
        identical = bool(corpus["benchmarks"].get(name, {}).get("identical_all_runs"))
    summaries = [line.split()[1] for line in path.read_text().splitlines()
                 if line.startswith("summary:")]
    if len(summaries) != 1:
        raise SystemExit(f"expected one summary in {path}")
    rows.setdefault(name, {})[side] = (int(summaries[0]), identical)
expected = len(corpus["benchmarks"]) + (1 if group == "mixed" else 0)
if len(rows) != expected:
    raise SystemExit(f"{group}: expected {expected} profiles, found {len(rows)}")
with output.open("w", newline="", encoding="utf-8") as stream:
    writer = csv.writer(stream)
    writer.writerow(["measurement_base", "group", "benchmark", "reference_ir",
                     "candidate_ir", "delta_pct", "output_identical"])
    for name, sides in sorted(rows.items()):
        if set(sides) != {"reference", "candidate"}:
            raise SystemExit(f"incomplete reference/candidate profiles for {name}")
        ref, ref_same = sides["reference"]
        cand, cand_same = sides["candidate"]
        identical = ref_same and cand_same
        if not identical:
            raise SystemExit(f"output mismatch for {name}")
        writer.writerow(["c7ebca768c21c251d9c165c9aff0e363768030b1", group,
                         name, ref, cand, f"{(cand-ref)*100/ref:.6f}", "yes"])
PY
sha256sum "$RESULTS/corpus.json" "$RESULTS/instruction-counts.csv" "$RESULTS/provenance.txt" \
  "$RESULTS/provenance-hashes.txt" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
