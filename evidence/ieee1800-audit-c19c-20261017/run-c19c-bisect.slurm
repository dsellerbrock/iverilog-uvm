#!/usr/bin/env bash
#SBATCH --job-name=a3-1800-c19c-bisect
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19c-20261017-02/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19c-20261017-02
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RUN/results.txt") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

echo "SOURCE_COMMIT=0ee663139"
echo "Bisection: coverpoint two-argument overload, group overload control, implicit-name control, minimal extends"
hostname; uname -a; date -Is; nproc
"$TOOL/bin/iverilog" -V > "$RESULTS/iverilog-version.log" 2>&1
sed -n '1,3p' "$RESULTS/iverilog-version.log"
sha256sum "$TOOL/bin/iverilog" "$TOOL/bin/vvp" "$RUN/input"/*.sv "$RUN/input/neg"/*.sv
compile_run() {
    label=$1; edition=$2; source=$3
    printf '\n=== %s (-g%s, expected compile/run) ===\n' "$label" "$edition"
    set +e; timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$RESULTS/$label.vvp" "$RUN/input/$source" > "$RESULTS/$label.compile.log" 2>&1; rc=$?; set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -ne 0 ]]; then echo PROBE_COMPILE_FAILED; status=1; return; fi
    set +e; timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$RESULTS/$label.vvp" > "$RESULTS/$label.run.log" 2>&1; run_rc=$?; set -e
    echo "run_rc=$run_rc"; cat "$RESULTS/$label.run.log"
    if [[ $run_rc -ne 0 ]] || grep -q '^FAIL ' "$RESULTS/$label.run.log"; then status=1; fi
}
compile_reject() {
    label=$1; edition=$2; source=$3; reason=$4
    printf '\n=== %s (-g%s, expected reject: %s) ===\n' "$label" "$edition" "$reason"
    set +e; timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$RESULTS/$label.vvp" "$RUN/input/$source" > "$RESULTS/$label.compile.log" 2>&1; rc=$?; set -e
    echo "compile_rc=$rc"; cat "$RESULTS/$label.compile.log"
    if [[ $rc -eq 0 ]]; then echo UNEXPECTED_ACCEPTANCE; status=1
    elif [[ $reason == undefined-base && $edition == 2023 ]]; then
        if grep -Eqi 'error:.*(nope|undefined|not.*base|base.*not)' "$RESULTS/$label.compile.log"; then echo EXPECTED_UNDEFINED_BASE_DIAGNOSTIC
        else echo SYNTAX_REJECTION_NOT_SPECIFIC; fi
    else echo EXPECTED_REJECTION; fi
}
for edition in 2017 2023; do
    compile_run "cp-twoarg-$edition" "$edition" p19_08_two_arg_cp_only.sv
    compile_run "cg-twoarg-$edition" "$edition" p19_08_two_arg_cg_only.sv
    compile_run "implicit-named-control-$edition" "$edition" p19_05_implicit_cp_named_control.sv
    if [[ $edition == 2017 ]]; then compile_reject "extends-minimal-$edition" "$edition" p19_04_1_extends_minimal.sv edition-only
    else compile_run "extends-minimal-$edition" "$edition" p19_04_1_extends_minimal.sv; fi
    compile_reject "extends-undefined-$edition" "$edition" neg/n19_04_1_extends_undefined.sv undefined-base
done
echo "RESULT=$([[ $status -eq 0 ]] && echo PASS || echo FINDINGS)"
exit "$status"
