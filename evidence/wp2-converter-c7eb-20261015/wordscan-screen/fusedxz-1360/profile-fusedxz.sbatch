#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp2-fusedxz
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-20261015-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-20261015-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-20261015-r1
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
BASE_SOURCE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/reference/source
REF_INSTALL=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install
SNAPSHOT=$ROOT/candidate/source-snapshot
CAND_SOURCE=$ROOT/build/candidate/source
CAND_INSTALL=$ROOT/build/candidate/install
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools/root
INPUT=$ROOT/input
RESULTS=$ROOT/results
VALGRIND=$TOOLS/usr/bin/valgrind
ANNOTATE=$TOOLS/usr/bin/callgrind_annotate
mkdir -p "$ROOT/logs" "$ROOT/build/candidate" "$ROOT/programs" "$ROOT/profiles" "$RESULTS"
finish() { local rc=$?; trap - EXIT; printf '%s\n' "$rc" > "$RESULTS/job-exit-code"; touch "$RESULTS/DONE"; exit "$rc"; }
trap finish EXIT
export VALGRIND_LIB="$TOOLS/usr/libexec/valgrind"
test -x "$REF_INSTALL/bin/iverilog" && test -x "$REF_INSTALL/bin/vvp"
test -x "$VALGRIND" && test -x "$ANNOTATE"
test -f "$BASE_SOURCE/Makefile.in" && test -f "$SNAPSHOT/Makefile.in"
printf 'measurement_base=%s\nreference_source=%s\ncandidate_patch_sha256=%s\n' \
  "$BASE" "$BASE_SOURCE" "$(sha256sum "$INPUT/candidate.patch" | cut -d' ' -f1)" > "$RESULTS/provenance.txt"
sha256sum "$INPUT/converter-wide-index.sv" "$INPUT/sv_vpi_wide_index.v" >> "$RESULTS/provenance.txt"

run_side() {
  side=$1
  install=$2
  mkdir -p "$ROOT/programs/$side" "$ROOT/profiles/$side"
  "$install/bin/iverilog" -g2012 -s converter_wide_index -o "$ROOT/programs/$side/converter.vvp" \
    "$INPUT/converter-wide-index.sv" > "$ROOT/programs/$side/compile.log" 2>&1
  timeout --signal=TERM --kill-after=15s 1200s "$VALGRIND" --quiet --tool=callgrind \
    --callgrind-out-file="$ROOT/profiles/$side/callgrind.out" \
    "$install/bin/vvp" "$ROOT/programs/$side/converter.vvp" \
    > "$RESULTS/$side.out" 2> "$RESULTS/$side.err"
  grep -q '^PASS wide converter screen ' "$RESULTS/$side.out"
  "$ANNOTATE" --inclusive=yes "$ROOT/profiles/$side/callgrind.out" > "$ROOT/profiles/$side/inclusive.txt"
  "$install/bin/iverilog" -g2012 -s sv_vpi_wide_index -o "$ROOT/programs/$side/wide-index.vvp" \
    "$INPUT/sv_vpi_wide_index.v" > "$ROOT/programs/$side/wide-index-compile.log" 2>&1
  timeout --signal=TERM --kill-after=15s 1200s "$install/bin/vvp" "$ROOT/programs/$side/wide-index.vvp" \
    > "$RESULTS/$side.edge.out" 2> "$RESULTS/$side.edge.err"
  grep -q '^PASS sv_vpi_wide_index$' "$RESULTS/$side.edge.out"
}

run_side reference "$REF_INSTALL"
cp -a "$SNAPSHOT" "$CAND_SOURCE"
(
  cd "$CAND_SOURCE"
  sh autoconf.sh > "$ROOT/logs/autoconf-candidate.log" 2>&1
  ./configure --prefix="$CAND_INSTALL" --enable-libveriuser CFLAGS='-g0 -O2' CXXFLAGS='-g0 -O2' \
    > "$ROOT/logs/configure-candidate.log" 2>&1
  make -j2 > "$ROOT/logs/build-candidate.log" 2>&1
  make install > "$ROOT/logs/install-candidate.log" 2>&1
)
run_side candidate "$CAND_INSTALL"
cmp "$RESULTS/reference.out" "$RESULTS/candidate.out"
cmp "$RESULTS/reference.err" "$RESULTS/candidate.err"
cmp "$RESULTS/reference.edge.out" "$RESULTS/candidate.edge.out"
cmp "$RESULTS/reference.edge.err" "$RESULTS/candidate.edge.err"
python3 - "$ROOT/profiles/reference/callgrind.out" "$ROOT/profiles/candidate/callgrind.out" "$RESULTS/instructions.csv" <<'PY'
from pathlib import Path
import sys
ref, cand, out = map(Path, sys.argv[1:])
def ir(path):
    rows = [line.split()[1] for line in path.read_text().splitlines()
            if line.startswith("summary:")]
    if len(rows) != 1:
        raise SystemExit(f"expected one instruction summary in {path}")
    return int(rows[0])
r, c = ir(ref), ir(cand)
out.write_text("measurement_base,reference_instructions,candidate_instructions,delta_pct\n"
               f"c7ebca768c21c251d9c165c9aff0e363768030b1,{r},{c},{(c-r)*100/r:.6f}\n")
PY
sha256sum "$RESULTS/reference.out" "$RESULTS/candidate.out" "$RESULTS/reference.edge.out" \
  "$RESULTS/candidate.edge.out" "$RESULTS/instructions.csv" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
