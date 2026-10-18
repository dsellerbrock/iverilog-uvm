#!/usr/bin/env bash
#SBATCH --job-name=a3-1800-c19b-bisect2
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19b-20261017-03/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19b-20261017-03
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/combined.txt") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

echo "SOURCE_COMMIT=16404e84d"
echo "Bisection: explicit coverpoint identifier and executable §19.4 assignment test"
hostname; uname -a; date -Is; nproc
"$TOOL/bin/iverilog" -V > "$RESULTS/iverilog-version.log" 2>&1
sed -n '1,3p' "$RESULTS/iverilog-version.log"
sha256sum "$TOOL/bin/iverilog" "$TOOL/bin/vvp" "$RUN/input"/*.sv
run_case() {
    label=$1; edition=$2; source=$3; semantic_expectation=$4
    printf '\n=== %s (-g%s) ===\n' "$label" "$edition"
    set +e
    timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$RESULTS/$label.vvp" "$RUN/input/$source" > "$RESULTS/$label.compile.log" 2>&1
    rc=$?
    set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -ne 0 ]]; then
        if [[ $semantic_expectation == reject ]]; then
            echo SPEC_REJECTION_ENFORCED
        else
            status=1
        fi
        return
    fi
    set +e
    timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$RESULTS/$label.vvp" > "$RESULTS/$label.run.log" 2>&1
    run_rc=$?
    set -e
    echo "run_rc=$run_rc"; cat "$RESULTS/$label.run.log"
    if [[ $run_rc -ne 0 ]] || grep -q '^FAIL ' "$RESULTS/$label.run.log"; then status=1; fi
    if [[ $semantic_expectation == reject ]]; then
        echo "SPEC_REQUIRES_REJECTION; observed compile accepted and runtime completed"
        status=1
    fi
}
for edition in 2017 2023; do
    run_case "cp-method-$edition" "$edition" p19_08_cp_method.sv supported
    run_case "type-methods-$edition" "$edition" p19_08_type_methods.sv supported
    run_case "embedded-event-$edition" "$edition" p19_04_embedded_event.sv supported
    run_case "assignment-outside-new-$edition" "$edition" p19_04_assignment_exec.sv reject
done
echo "RESULT=$([[ $status -eq 0 ]] && echo PASS || echo FINDINGS)"
exit "$status"
