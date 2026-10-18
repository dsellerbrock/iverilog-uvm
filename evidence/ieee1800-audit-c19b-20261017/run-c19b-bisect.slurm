#!/usr/bin/env bash
#SBATCH --job-name=a3-1800-c19b-bisect
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19b-20261017-02/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19b-20261017-02
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/combined.txt") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

echo "SOURCE_COMMIT=16404e84d"
echo "SOURCE_DIRTY=uncommitted c19b probes; bisection inputs staged"
hostname; uname -a; date -Is; nproc
"$TOOL/bin/iverilog" -V > "$RESULTS/iverilog-version.log" 2>&1
sed -n '1,3p' "$RESULTS/iverilog-version.log"
sha256sum "$TOOL/bin/iverilog" "$TOOL/bin/vvp" "$RUN/input"/*.sv "$RUN/input/neg"/*.sv
run_positive() {
    label=$1; edition=$2; source=$3
    printf '\n=== %s (-g%s, expected=run) ===\n' "$label" "$edition"
    set +e
    timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$RESULTS/$label.vvp" "$RUN/input/$source" > "$RESULTS/$label.compile.log" 2>&1
    rc=$?
    set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -ne 0 ]]; then status=1; return; fi
    set +e
    timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$RESULTS/$label.vvp" > "$RESULTS/$label.run.log" 2>&1
    rc=$?
    set -e
    echo "run_rc=$rc"; cat "$RESULTS/$label.run.log"
    if [[ $rc -ne 0 ]] || grep -q '^FAIL ' "$RESULTS/$label.run.log"; then status=1; fi
}
run_reject() {
    label=$1; edition=$2; source=$3
    printf '\n=== %s (-g%s, expected=reject) ===\n' "$label" "$edition"
    set +e
    timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$RESULTS/$label.vvp" "$RUN/input/$source" > "$RESULTS/$label.compile.log" 2>&1
    rc=$?
    set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -eq 0 ]] || grep -qi 'No top level modules' "$RESULTS/$label.compile.log"; then
        echo UNEXPECTED_ACCEPTANCE_OR_ROOT; status=1
    else echo EXPECTED_REJECTION; fi
    if [[ $label == neg-assign-* && $rc -eq 0 ]]; then
        set +e
        timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$RESULTS/$label.vvp" > "$RESULTS/$label.run.log" 2>&1
        run_rc=$?
        set -e
        echo "run_rc=$run_rc"; cat "$RESULTS/$label.run.log"
    fi
}
for edition in 2017 2023; do
    run_positive "core-$edition" "$edition" p19_03_core.sv
    run_positive "cp-method-$edition" "$edition" p19_08_cp_method.sv
    run_positive "type-methods-$edition" "$edition" p19_08_type_methods.sv
    run_positive "sample-controls-$edition" "$edition" p19_08_sample_controls.sv
    run_positive "set-inst-name-$edition" "$edition" p19_08_set_inst_name.sv
    run_positive "embedded-event-$edition" "$edition" p19_04_embedded_event.sv
    run_positive "block-event-$edition" "$edition" p19_03_block_event.sv
    run_reject "neg-output-$edition" "$edition" neg/n19_03_output_formal.sv
    run_reject "neg-extends-$edition" "$edition" neg/n19_03_extends_outside_class.sv
    run_reject "neg-assign-$edition" "$edition" neg/n19_04_assign_outside_new.sv
done
echo "RESULT=$([[ $status -eq 0 ]] && echo PASS || echo FINDINGS)"
exit "$status"
