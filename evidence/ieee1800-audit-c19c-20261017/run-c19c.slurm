#!/usr/bin/env bash
#SBATCH --job-name=a3-1800-c19c
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19c-20261017-01/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19c-20261017-01
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RUN/results.txt") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

echo "SOURCE_COMMIT=0ee663139"
echo "IEEE_PROBE=c19c; two editions"
hostname; uname -a; date -Is; nproc
"$TOOL/bin/iverilog" -V > "$RESULTS/iverilog-version.log" 2>&1
sed -n '1,3p' "$RESULTS/iverilog-version.log"
sha256sum "$TOOL/bin/iverilog" "$TOOL/bin/vvp" "$RUN/input"/*.sv "$RUN/input/neg"/*.sv

compile() {
    label=$1; edition=$2; source=$3; top=$4
    local out="$RESULTS/$label.compile.log"
    if [[ $top == top ]]; then
        timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$RESULTS/$label.vvp" "$RUN/input/$source" > "$out" 2>&1
    else
        timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -o "$RESULTS/$label.vvp" "$RUN/input/$source" > "$out" 2>&1
    fi
}
run_positive() {
    label=$1; edition=$2; source=$3
    printf '\n=== %s (-g%s, expected run) ===\n' "$label" "$edition"
    set +e; compile "$label" "$edition" "$source" top; rc=$?; set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -ne 0 ]]; then status=1; return; fi
    set +e; timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$RESULTS/$label.vvp" > "$RESULTS/$label.run.log" 2>&1; run_rc=$?; set -e
    echo "run_rc=$run_rc"; cat "$RESULTS/$label.run.log"
    if [[ $run_rc -ne 0 ]] || grep -q '^FAIL ' "$RESULTS/$label.run.log"; then status=1; fi
}
run_reject() {
    label=$1; edition=$2; source=$3; reason=$4
    printf '\n=== %s (-g%s, expected reject: %s) ===\n' "$label" "$edition" "$reason"
    set +e; compile "$label" "$edition" "$source" top; rc=$?; set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -eq 0 ]]; then echo UNEXPECTED_ACCEPTANCE; status=1; return; fi
    if [[ $reason == undefined-base && $edition == 2023 ]]; then
        if grep -Eqi 'error:.*(nope|undefined|not.*base|base.*not)' "$RESULTS/$label.compile.log"; then echo EXPECTED_UNDEFINED_BASE_DIAGNOSTIC;
        else echo SYNTAX_REJECTION_NOT_SPECIFIC; fi
    else echo EXPECTED_REJECTION; fi
}
run_two_arg_inst() {
    label=$1; edition=$2; source=$3
    printf '\n=== %s (-g%s, two-argument totals) ===\n' "$label" "$edition"
    set +e; compile "$label" "$edition" "$source" top; rc=$?; set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -ne 0 ]]; then status=1; return; fi
    set +e; timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$RESULTS/$label.vvp" > "$RESULTS/$label.run.log" 2>&1; run_rc=$?; set -e
    echo "run_rc=$run_rc"; cat "$RESULTS/$label.run.log"
    if [[ $run_rc -ne 0 ]]; then status=1; return; fi
    if grep -q '^FAIL 19\.8\.cp_inst cov=0 tot=0$' "$RESULTS/$label.run.log" && grep -q '^FAIL 19\.8\.cg_inst cov=0 tot=0$' "$RESULTS/$label.run.log"; then
        echo KNOWN_GAP_622_ALSO_COVERS_COVERPOINT_FORM
    elif ! grep -q '^PASS 19\.8\.cp_inst' "$RESULTS/$label.run.log" || ! grep -q '^PASS 19\.8\.cg_inst' "$RESULTS/$label.run.log"; then
        echo TWO_ARGUMENT_RESULT_NEEDS_LEAD_CLASSIFICATION
    fi
}
run_type_methods() {
    label=$1; edition=$2; source=$3
    printf '\n=== %s (-g%s, type-level two-argument totals) ===\n' "$label" "$edition"
    set +e; compile "$label" "$edition" "$source" top; rc=$?; set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -ne 0 ]]; then echo INCONCLUSIVE_BLOCKED_BY_627; return; fi
    set +e; timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$RESULTS/$label.vvp" > "$RESULTS/$label.run.log" 2>&1; run_rc=$?; set -e
    echo "run_rc=$run_rc"; cat "$RESULTS/$label.run.log"
    if [[ $run_rc -ne 0 ]] || grep -q '^FAIL ' "$RESULTS/$label.run.log"; then status=1; fi
}
for edition in 2017 2023; do
    run_positive "clock-event-$edition" "$edition" p19_03_clock_event.sv
    run_two_arg_inst "two-arg-inst-$edition" "$edition" p19_08_two_arg_inst.sv
    run_type_methods "two-arg-type-$edition" "$edition" p19_08_two_arg_type.sv
    run_positive "implicit-cp-$edition" "$edition" p19_05_implicit_cp_name.sv
    if [[ $edition == 2017 ]]; then
        run_reject "extends-positive-$edition" "$edition" p19_04_1_extends_2023.sv edition-only
    else
        run_positive "extends-positive-$edition" "$edition" p19_04_1_extends_2023.sv
    fi
    run_reject "extends-undefined-$edition" "$edition" neg/n19_04_1_extends_undefined.sv undefined-base
done
echo "RESULT=$([[ $status -eq 0 ]] && echo PASS || echo FINDINGS)"
exit "$status"
