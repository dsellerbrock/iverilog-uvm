#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-fst-repro
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020
SOURCE=$ROOT/source/candidate
mkdir -p "$ROOT/debug/fst" "$ROOT/results"
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/fst-repro-exit-code"
    touch "$ROOT/results/fst-repro-DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C "$ROOT/source/reference" rev-parse HEAD)" = 8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1
test "$(git -C "$SOURCE" rev-parse HEAD)" = 8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1
cmp "$ROOT/results/reused-candidate.patch" "$ROOT/input/candidate.patch"
cmp "$ROOT/results/reused-stats.patch" "$ROOT/input/candidate.patch"
CPU=$(awk '/Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
export VALGRIND_LIB=/usr/libexec/valgrind
export IVERILOG=$ROOT/install/candidate/bin/iverilog
export IVERILOG_VPI=$ROOT/install/candidate/bin/iverilog-vpi
export UVM_DPI=$ROOT/install/candidate/lib/ivl/uvm_dpi.vpi

python3 - "$ROOT" "$CPU" <<'PY'
import json, os, subprocess, sys
from pathlib import Path
root, cpu = Path(sys.argv[1]), int(sys.argv[2])
sys.path.insert(0, str(root / "source/candidate/benchmarks/sim-hotspots"))
import run_json
program_dir = root / "debug/fst"
program = program_dir / "waveform_fst.vvp"
compiler = run_json.command_words("IVERILOG", "iverilog")
compiled = run_json.run_process([*compiler, "-g2012", "-o", str(program),
    str(root / "source/candidate/benchmarks/sim-hotspots/waveform.sv")],
    cwd=program_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
if compiled.returncode:
    raise SystemExit(compiled.stdout.decode(errors="replace")[-4000:])
outputs = {}
for side in ("reference", "candidate"):
    run_dir = program_dir / ("plain-" + side)
    run_dir.mkdir()
    command = [str(root / f"install/{side}/bin/vvp"), "-n", str(program),
               "+use_fst", "-fst", "-no-date"]
    env = os.environ.copy(); env["LC_ALL"] = "C"
    os.sched_setaffinity(0, {cpu})
    result = run_json.run_process(command, cwd=run_dir, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=1200)
    if result.returncode:
        raise SystemExit(f"{side} plain FST exit {result.returncode}: "
                         f"{result.stdout.decode(errors='replace')[-2000:]}")
    outputs[side] = run_json.hash_outputs(run_dir)
if outputs["reference"] != outputs["candidate"]:
    raise SystemExit("plain reference/candidate FST outputs differ")
(root / "results/fst-repro-plain.json").write_text(
    json.dumps({side: {"sha256": value[0], "files": value[1]}
                for side, value in outputs.items()}, indent=2, sort_keys=True) + "\n")
PY

set +e
python3 - "$ROOT" <<'PY' > "$ROOT/results/fst-repro-callgrind.json"
import sys
from pathlib import Path
root = Path(sys.argv[1])
sys.path.insert(0, str(root / "source/candidate/benchmarks/sim-hotspots"))
import run_json_callgrind
run_json_callgrind.BENCHMARKS = ("waveform_fst",)
for side in ("reference", "candidate"):
    wrapper = root / f"runners/fst-repro-{side}"
    wrapper.write_text("#!/usr/bin/env bash\nset -Eeuo pipefail\n"
        "exec /usr/bin/valgrind --quiet --tool=callgrind --fair-sched=yes "
        f"--callgrind-out-file={root}/profiles/fst-repro-{side}.callgrind "
        f"{root}/install/{side}/bin/vvp \"$@\"\n")
    wrapper.chmod(0o755)
sys.exit(run_json_callgrind.main([
    str(root / "runners/fst-repro-reference"),
    str(root / "runners/fst-repro-candidate"), "1"]))
PY
rc=$?
set -e
test "$rc" -eq 0
