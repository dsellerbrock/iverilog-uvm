#!/usr/bin/env bash
#SBATCH --job-name=a5-wp10-r4-screen
#SBATCH --partition=verilog
#SBATCH --array=0-1%1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-constant-shift-c344-20261018-r4
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-constant-shift-c344-20261018-r4/logs/%x-%A_%a.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-constant-shift-c344-20261018-r4
REF_INSTALL=$ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
INPUT=$ROOT/input
SOURCE=$ROOT/source/candidate
PROFILES=$ROOT/profiles
SCREEN_DIR=$ROOT/screen
mkdir -p "$PROFILES" "$SCREEN_DIR" "$ROOT/logs"

test -f "$ROOT/results/BUILD_SUCCESS"
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
(
  cd "$INPUT"
  sha256sum --check source-inputs.sha256
)
case "${SLURM_ARRAY_TASK_ID:?}" in
  0) GROUP=rtl; BENCHMARKS=(rtl_pipe rtl_alu wide_vectors gate_strength multi_clock large_memory vpi_callbacks waveform_fst waveform_vcd) ;;
  1) GROUP=other; BENCHMARKS=(behav classq uvm_traffic randomize_z3 randomize_dv_txn strings_aa_queue uvm_config_factory fork_heavy io_text) ;;
  *) exit 2 ;;
esac
RESULTS=$SCREEN_DIR/$GROUP
mkdir -p "$RESULTS"
cp "$INPUT/run_wp10_screen.py" "$SOURCE/benchmarks/sim-hotspots/run_wp10_screen.py"
RUNNER=$SOURCE/benchmarks/sim-hotspots/run_wp10_screen.py
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
  local runtime=$1 path=$2
  cat > "$path" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
exec /usr/bin/valgrind --quiet --tool=callgrind \\
  --callgrind-out-file="$PROFILES/\$name.callgrind" \\
  --log-file="$PROFILES/\$name.valgrind.log" "$runtime" "\$@"
WRAPPER
  chmod +x "$path"
}
make_wrapper "$REF_INSTALL/bin/vvp" "$RESULTS/callgrind-reference"
make_wrapper "$CAND_INSTALL/bin/vvp" "$RESULTS/callgrind-candidate"

export VALGRIND_LIB=/usr/libexec/valgrind
export IVERILOG_REFERENCE=$REF_INSTALL/bin/iverilog
export IVERILOG_CANDIDATE=$CAND_INSTALL/bin/iverilog
export IVERILOG_VPI_REFERENCE=$REF_INSTALL/bin/iverilog-vpi
export IVERILOG_VPI_CANDIDATE=$CAND_INSTALL/bin/iverilog-vpi
export UVM_DPI_REFERENCE=$REF_INSTALL/lib/ivl/uvm_dpi.vpi
export UVM_DPI_CANDIDATE=$CAND_INSTALL/lib/ivl/uvm_dpi.vpi
timeout --signal=TERM --kill-after=30s 14400s \
  python3 "$RUNNER" "$RESULTS/callgrind-reference" \
  "$RESULTS/callgrind-candidate" 1 > "$RESULTS/corpus.json"
touch "$RESULTS/SUCCESS"
