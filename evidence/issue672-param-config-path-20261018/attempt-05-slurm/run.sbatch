#!/usr/bin/env bash
#SBATCH --job-name=a3-672-param-path-t0t1
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue672-config-path-20261018-02/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue672-config-path-20261018-02
ROOT="$RUN/source"
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/t0t1-combined.log") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT
cd "$ROOT"
printf 'source_head=bac2fc96a\n' > "$RESULTS/source-head.txt"
printf '%s\n' '--- host ---'
printf 'hostname=%s\n' "$(hostname)"
uname -a
date -Is
nproc
free -h
run_step() {
    label=$1
    limit=$2
    shift 2
    printf '\n=== %s (timeout %ss) ===\n' "$label" "$limit"
    set +e
    /usr/bin/time -v python3 "$ROOT/scripts/run_with_timeout.py" "$limit" -- "$@" > "$RESULTS/$label.log" 2>&1
    rc=$?
    set -e
    printf 'step_exit=%s\n' "$rc"
    tail -35 "$RESULTS/$label.log"
    if [[ $rc -ne 0 ]]; then status=1; fi
}
run_step configure-script 120 autoconf
run_step configure 300 ./configure --enable-libveriuser --prefix="$ROOT/local-install"
run_step build 1200 make -j2
run_step install 240 make install
if [[ $status -ne 0 ]]; then
    printf '\nGATE_RESULT=FAIL (build stage)\n'
    exit 1
fi
export PATH="$ROOT/local-install/bin:$PATH"
iverilog -V > "$RESULTS/iverilog-version.log" 2>&1
vvp -V > "$RESULTS/vvp-version.log" 2>&1
sha256sum "$ROOT/local-install/bin/iverilog" "$ROOT/local-install/bin/vvp" > "$RESULTS/compiler.sha256"
python3 - "$ROOT" "$RESULTS" <<'PY'
from pathlib import Path
import sys
root, results = map(Path, sys.argv[1:])
names = ["sv_param_config_seed_deferral_2017", "sv_param_config_seed_deferral_2023"]
for source, output in (("ivtest/regress-sv.list", "t0-sv.list"),
                       ("ivtest/regress-vvp.list", "t0-json.list")):
    rows = [line.strip() for line in (root / source).read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")]
    selected = []
    for name in names:
        matches = [line for line in rows if line.split()[0] == name]
        if len(matches) != 1:
            raise SystemExit(f"{source}: {name} has {len(matches)} entries")
        selected.extend(matches)
    (results / output).write_text("\n".join(selected) + "\n")
    print(f"{output}: {len(selected)} tests")
PY
cd "$ROOT/ivtest"
run_step t0-legacy 900 perl ./vvp_reg.pl "$RESULTS/t0-sv.list"
run_step t0-json 1800 python3 "$ROOT/scripts/run_json_manifest.py" "$RESULTS/t0-json.list" "$RESULTS/t0-json-cases" 300 "$ROOT"
cd "$ROOT"
run_step t0-smoke 3600 bash ./ci/run-smoke.sh
cd "$ROOT/ivtest"
run_step t1-legacy 3600 perl ./vvp_reg.pl "$ROOT/ivtest/regress-vif-parameter-specialization-focus-legacy.list"
run_step t1-json 3600 python3 "$ROOT/scripts/run_json_manifest.py" "$ROOT/ivtest/regress-vif-parameter-specialization-focus-vvp.list" "$RESULTS/t1-json-cases" 300 "$ROOT"
printf '\nGATE_RESULT=%s\n' "$( [[ $status -eq 0 ]] && echo PASS || echo FAIL )"
exit "$status"
