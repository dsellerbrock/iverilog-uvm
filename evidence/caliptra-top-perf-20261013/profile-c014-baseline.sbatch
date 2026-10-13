#!/usr/bin/env bash
#SBATCH --job-name=a3-perf536-c014
#SBATCH --cpus-per-task=3
#SBATCH --mem=3G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/perf-536-c014-baseline-20261013-01/logs/%x-%j.out

set -Eeuo pipefail

RUN=${SLURM_SUBMIT_DIR:?}
QD=/home/dsell/toolchains/qd-bfm-8e34e0c
BUILT=/home/dsell/toolchains/iverilog-c339
RTL=$BUILT/firmware/caliptra-rtl
IVERILOG=$RUN/install/bin
ENV=$BUILT/deps
GCC_DIR=$BUILT/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
GCC=$GCC_DIR/riscv-none-elf-
OPENSSL=$BUILT/openssl
JTAG_VPI=$BUILT/firmware/jtagdpi/jtagdpi.vpi
RUNNER=$QD/dv/caliptra_bfm/uvm/tests/run_caliptra_top_firmware_bfm.py

mkdir -p "$RUN/logs" "$RUN/window" "$RUN/profile" "$RUN/pycache"
cd "$RUN/source"
sh autoconf.sh
./configure --prefix="$RUN/install"
make -j"${SLURM_CPUS_PER_TASK:-3}"
make install
cp "$RUN/input/mcycle-window-vpi.c" "$RUN/window/"
cd "$RUN/window"
"$IVERILOG/iverilog-vpi" mcycle-window-vpi.c
test -s mcycle-window-vpi.vpi

cp "$RUNNER" "$RUN/run_caliptra_window.py"
chmod u+w "$RUN/run_caliptra_window.py"
"$ENV/bin/python3.12" - "$RUN/run_caliptra_window.py" <<'PY'
from pathlib import Path
import difflib
import sys

runner = Path(sys.argv[1])
before = runner.read_text()
after = before
old_repo = "REPO = Path(__file__).resolve().parents[4]"
new_repo = 'REPO = Path(os.environ["CALIPTRA_BFM_REPO"]).resolve()'
old_identity = '    path = Path(root).expanduser().resolve()\n\n    def git(*args):'
new_identity = '''    path = Path(root).expanduser().resolve()
    pin = path / "qd-bfm.commit"
    if pin.is_file():
        return {"root": str(path), "commit": pin.read_text().strip(),
                "clean": True, "remote_tracking_refs_containing_head": []}

    def git(*args):'''
old_command = '    command.extend([vvp, "-d", jtagdpi, "-n", "-m", progress_plugin, binary, *plusargs])'
new_command = '''    command.extend(["/usr/bin/perf", "record", "-F", "49", "-g", "--call-graph", "fp", "-o", os.environ["CALIPTRA_PERF_DATA"], "--", vvp, "-d", jtagdpi, "-n", "-m", progress_plugin, "-m", os.environ["CALIPTRA_MCYCLE_WINDOW_PLUGIN"], binary, *plusargs])'''
assert after.count(old_repo) == 1
assert after.count(old_identity) == 1
assert after.count(old_command) == 1
after = after.replace(old_repo, new_repo).replace(old_identity, new_identity).replace(old_command, new_command)
runner.write_text(after)
diff = difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                            fromfile="runner.original.py", tofile="runner.window-profile.py")
Path(runner.parent, "profile-runner.patch").write_text("".join(diff))
PY

QD_SHA=$(cat "$QD/qd-bfm.commit")
RTL_SHA=$(git -C "$RTL" rev-parse HEAD)
IVERILOG_SHA=$(cat "$RUN/SOURCE_SHA")
printf 'host=%s\nqd_bfm=%s\ncaliptra_rtl=%s\nicarus_source=%s\n' \
    "$(hostname)" "$QD_SHA" "$RTL_SHA" "$IVERILOG_SHA" | tee "$RUN/profile/provenance.txt"
sha256sum "$IVERILOG/vvp" "$IVERILOG/iverilog" "$JTAG_VPI" \
    "$RUN/window/mcycle-window-vpi.vpi" | tee "$RUN/profile/binaries.sha256"
"$IVERILOG/vvp" -V > "$RUN/profile/vvp-version.txt" 2>&1

export PATH="$ENV/bin:$IVERILOG:$GCC_DIR:$OPENSSL/bin:$PATH"
export LD_LIBRARY_PATH="$RUN/install/lib:$ENV/lib:$OPENSSL/lib"
export CALIPTRA_BFM_REPO="$QD"
export CALIPTRA_MBEDTLS_ROOT="$ENV"
export CALIPTRA_RTL="$RTL"
export CALIPTRA_GCC_PREFIX="$GCC"
export CALIPTRA_JTAGDPI_VPI="$JTAG_VPI"
export CALIPTRA_BFM_PROFILE="$RTL/src/integration/config/caliptra_top_tb.vf"
export CALIPTRA_PRIM_ROOT="$RTL/src/caliptra_prim_generic"
export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
export IVERILOG_BIN="$IVERILOG/iverilog"
export VVP_BIN="$IVERILOG/vvp"
export IVERILOG_VPI_BIN="$IVERILOG/iverilog-vpi"
# The staged source archive has no .git directory; SOURCE_SHA is recorded above.
unset IVERILOG_SOURCE_ROOT
export PYTHONPYCACHEPREFIX="$RUN/pycache"
export CALIPTRA_MCYCLE_WINDOW_PLUGIN="$RUN/window/mcycle-window-vpi.vpi"
export CALIPTRA_MCYCLE_WINDOW_START=100
export CALIPTRA_MCYCLE_WINDOW_END=600
export CALIPTRA_PERF_DATA="$RUN/profile/perf.data"

python3.12 -m py_compile "$RUN/run_caliptra_window.py"
set +e
/usr/bin/time -v -o "$RUN/profile/resource.txt" timeout --signal=INT --kill-after=60s 7200s \
    python3.12 "$RUN/run_caliptra_window.py" --case cptra_ss_test_rom \
    --case-yaml cptra_ss_test_rom/cptra_ss_test_rom.yml --output "$RUN/output" \
    > "$RUN/logs/runner.log" 2>&1
runner_exit=$?
set -e

SIM_LOG="$RUN/output/cptra_ss_test_rom/sim.log"
if ! grep '^MCYCLE_WINDOW ' "$SIM_LOG" > "$RUN/profile/window-result.txt"; then
    cat "$RUN/logs/runner.log"
    printf 'profile window marker missing; runner_exit=%s\n' "$runner_exit" | tee "$RUN/profile/status.txt"
    exit 1
fi
/usr/bin/perf report --stdio --no-children --sort=symbol -i "$RUN/profile/perf.data" \
    > "$RUN/profile/perf-report.txt"
printf 'window_complete=1\nrunner_exit=%s\nresult_json_passed=' "$runner_exit" \
    | tee "$RUN/profile/status.txt"
python3.12 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("passed"))' \
    "$RUN/output/result.json" >> "$RUN/profile/status.txt"
grep 'Maximum resident set size' "$RUN/profile/resource.txt" | tee -a "$RUN/profile/status.txt"
