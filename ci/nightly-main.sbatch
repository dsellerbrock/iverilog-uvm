#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=iverilog-main-nightly
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --export=ALL
set -euo pipefail

MAIN_SHA=${MAIN_SHA:?dispatcher must pass MAIN_SHA}
RUN_ROOT="$HOME/slurm-runs/iverilog-uvm/a4/nightly-main"
RUN="$RUN_ROOT/$SLURM_JOB_ID"
SOURCE="$RUN/source"
LOG="$RUN/full-gate.log"
RESULT="$HOME/codex-supervisor/nightly-main.json"
FAILED=setup
mkdir -p "$RUN" "$(dirname "$RESULT")"
exec > >(tee -a "$LOG") 2>&1

write_result() {
    local rc=$?
    trap - EXIT
    python3 - "$RESULT" "$MAIN_SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$([[ $rc -eq 0 ]] && echo true || echo false)" "$FAILED" "$LOG" <<'PY'
import json
import os
import sys
import tempfile

path, sha, date, passed, failed, log = sys.argv[1:]
value = {
    "sha": sha,
    "date": date,
    "passed": passed == "true",
    "failed": failed or None,
    "log": log,
}
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".nightly-main-")
with os.fdopen(fd, "w") as stream:
    json.dump(value, stream, indent=2)
    stream.write("\n")
os.replace(tmp, path)
PY
    exit "$rc"
}
trap write_result EXIT

step() {
    local name=$1
    shift
    FAILED=$name
    echo "=== $name ==="
    "$@"
    FAILED=
}

step checkout git clone --depth=1 --branch main --no-checkout \
    https://github.com/dsellerbrock/iverilog-uvm.git "$SOURCE"
step pin-main git -C "$SOURCE" fetch --depth=1 origin "$MAIN_SHA"
step checkout-sha git -C "$SOURCE" checkout --detach "$MAIN_SHA"
step submodules git -C "$SOURCE" submodule update --init --recursive --depth 1
cd "$SOURCE"
step docs-dependencies python3 -m venv "$RUN/docs-venv"
step docs-dependencies "$RUN/docs-venv/bin/pip" install \
    --disable-pip-version-check sphinx docopt
step autoconf autoconf
step configure ./configure --prefix="$SOURCE/local-install" --enable-libveriuser
step build make -j"${SLURM_CPUS_PER_TASK:-4}"
step self-check make check
step install make install
export PATH="$SOURCE/local-install/bin:$PATH"
step ivtest-gate bash .github/ivtest_gate.sh
step vif-function-focus bash .github/ivtest_focus_gate.sh \
    regress-vif-function-focus-legacy.list regress-vif-function-focus-vvp.list
step vif-specialization-focus bash .github/ivtest_focus_gate.sh \
    regress-vif-parameter-specialization-focus-legacy.list \
    regress-vif-parameter-specialization-focus-vvp.list
step uvm-regression bash .github/uvm_test.sh
step uvm-frontend bash .github/uvm_frontend_test.sh
step dpi-unsigned-char env IVERILOG="$(command -v iverilog)" \
    IVPI="$(command -v iverilog-vpi)" VVP="$SOURCE/vvp/vvp" \
    DPI_CHAR_CFLAGS=-funsigned-char bash tests/vvp_runtime/run_dpi_plain_char_abi.sh
step documentation env PATH="$RUN/docs-venv/bin:$PATH" \
    make -C Documentation html
FAILED=
