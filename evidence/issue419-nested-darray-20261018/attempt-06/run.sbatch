#!/usr/bin/env bash
#SBATCH --job-name=a3-419-nested-t0t1
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue419-nested-focused-t0t1-20261018-02/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue419-nested-focused-t0t1-20261018-02
ROOT="$RUN/source"
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/t0t1-combined.log") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT
cd "$ROOT"
hostname; uname -a; date -Is; nproc; free -h
run_step() {
    label=$1
    limit=$2
    shift 2
    printf '\n=== %s (timeout %ss) ===\n' "$label" "$limit"
    set +e
    python3 "$ROOT/scripts/run_with_timeout.py" "$limit" -- "$@" > "$RESULTS/$label.log" 2>&1
    rc=$?
    set -e
    printf 'step_exit=%s\n' "$rc"
    tail -40 "$RESULTS/$label.log"
    if [[ $rc -ne 0 ]]; then status=1; fi
}
run_step configure-script 120 autoconf
run_step configure 300 ./configure --enable-libveriuser --prefix="$ROOT/local-install"
run_step build 1200 make -j2
run_step install 240 make install
export PATH="$ROOT/local-install/bin:$PATH"
iverilog -V > "$RESULTS/iverilog-version.log" 2>&1
vvp -V > "$RESULTS/vvp-version.log" 2>&1
sha256sum "$ROOT/local-install/bin/iverilog" "$ROOT/local-install/bin/vvp" > "$RESULTS/compiler.sha256"
head -4 "$RESULTS/iverilog-version.log"; head -4 "$RESULTS/vvp-version.log"
python3 - "$ROOT" "$RESULTS" <<'PY'
from pathlib import Path
import sys
root, results = map(Path, sys.argv[1:])
issue = [
    "sv_randomize_struct_darray_member", "sv_randomize_struct_darray_member_2023",
    "sv_randomize_struct_nested_darray_member", "sv_randomize_struct_nested_darray_member_2023",
    "sv_randomize_struct_nested_darray_constraint", "sv_randomize_struct_nested_darray_constraint_2023",
]
neighbors = issue + [
    "sv_rand_array_mode_object_struct", "sv_rand_mode_dynamic_indexing",
    "sv_constraint_dynarray_packed_struct_member", "sv_constraint_dynarray_packed_struct_member_2023",
    "sv_constraint_nested_unpacked_struct", "sv_constraint_nested_unpacked_struct_2023",
    "sv_randomize_member_nested_hooks", "sv_randomize_member_nested_hooks_2023",
    "sv_struct_member_randomization",
]
for names, prefix in ((issue, "t0"), (neighbors, "t1")):
    for listname, outname in (("ivtest/regress-sv.list", f"{prefix}-sv.list"), ("ivtest/regress-vvp.list", f"{prefix}-json.list")):
        rows = [line.split() for line in (root / listname).read_text().splitlines()
                if line.strip() and not line.lstrip().startswith('#')]
        selected = []
        for name in names:
            matches = [row for row in rows if row[0] == name]
            if len(matches) != 1:
                raise SystemExit(f"{listname}: {name} has {len(matches)} entries")
            selected.append(' '.join(matches[0]))
        (results / outname).write_text('\n'.join(selected) + '\n')
        print(f"{outname}: {len(selected)} tests")
PY
cd "$ROOT/ivtest"
run_step t0-legacy 900 perl ./vvp_reg.pl "$RESULTS/t0-sv.list"
run_step t0-json 900 python3 ./vvp_reg.py "$RESULTS/t0-json.list"
cd "$ROOT"
run_step t0-smoke 3600 bash ./ci/run-smoke.sh
cd "$ROOT/ivtest"
run_step t1-legacy 1800 perl ./vvp_reg.pl "$RESULTS/t1-sv.list"
run_step t1-json 1800 python3 ./vvp_reg.py "$RESULTS/t1-json.list"
printf '\nGATE_RESULT=%s\n' "$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
