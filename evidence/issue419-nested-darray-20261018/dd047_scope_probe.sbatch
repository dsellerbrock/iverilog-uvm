#!/usr/bin/env bash
#SBATCH --job-name=a3-419-dd047-probe
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue419-dd047-scope-probe-20261018-01/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue419-dd047-scope-probe-20261018-01
ROOT="$RUN/source"
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/probe.log") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT
cd "$ROOT"
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
    cat "$RESULTS/$label.log"
    if [[ $rc -ne 0 ]]; then status=1; fi
}
run_step autoconf 120 autoconf
run_step configure 300 ./configure --enable-libveriuser --prefix="$ROOT/local-install"
run_step build 1200 make -j2
run_step install 240 make install
export PATH="$ROOT/local-install/bin:$PATH"
sha256sum "$ROOT/local-install/bin/iverilog" "$ROOT/local-install/bin/vvp" > "$RESULTS/compiler.sha256"
for edition in 2017 2023; do
    run_step "compile-$edition" 60 iverilog "-g$edition" -s reducer -o "$RESULTS/dd047-$edition.vvp" \
        "$RUN/dd047_nested_resize.sv"
    run_step "run-$edition" 60 vvp -n "$RESULTS/dd047-$edition.vvp"
done
printf '\nGATE_RESULT=%s\n' "$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
