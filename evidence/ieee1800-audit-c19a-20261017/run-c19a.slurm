#!/usr/bin/env bash
#SBATCH --job-name=a3-1800-c19a
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19a-20261017-01/logs/%x-%j.out
set -Eeuo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19a-20261017-01
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/combined.txt") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

echo "SOURCE_REVISION=5ee99d8dd"
hostname; uname -a; date -Is; nproc
"$TOOL/bin/iverilog" -V >"$RESULTS/iverilog-version.log" 2>&1
sed -n '1,3p' "$RESULTS/iverilog-version.log"
sha256sum "$TOOL/bin/iverilog" "$TOOL/bin/vvp" "$RUN/input"/*.sv

run_case() {
    label=$1
    edition=$2
    source=$3
    expected=$4
    image="$RESULTS/$label.vvp"
    compile_log="$RESULTS/$label.compile.log"
    run_log="$RESULTS/$label.run.log"
    printf '\n=== %s (-g%s, expected=%s) ===\n' "$label" "$edition" "$expected"
    set +e
    timeout 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$image" "$RUN/input/$source" >"$compile_log" 2>&1
    compile_rc=$?
    set -e
    echo "compile_rc=$compile_rc"
    cat "$compile_log"
    if [[ $expected == reject ]]; then
        if [[ $compile_rc -ne 0 ]]; then echo EXPECTED_REJECTION; else echo UNEXPECTED_ACCEPTANCE; status=1; fi
        return
    fi
    if [[ $compile_rc -ne 0 ]]; then status=1; return; fi
    set +e
    timeout 30 "$TOOL/bin/vvp" "$image" >"$run_log" 2>&1
    run_rc=$?
    set -e
    echo "run_rc=$run_rc"
    cat "$run_log"
    if [[ $run_rc -ne 0 ]] || grep -q '^FAIL ' "$run_log"; then status=1; return; fi
    if [[ $label == bins-* ]]; then
        grep -q '^DONE fails=0$' "$run_log" || status=1
        grep -q 'INFO cg1 cov=.* n=5 d=70' "$run_log" || status=1
        grep -q 'INFO cg3 cov=.* n=1 d=3' "$run_log" || status=1
    else
        [[ $(grep -c '^PASS 19\.5\.tolerance_' "$run_log") -eq 2 ]] || status=1
    fi
}

run_case bins-2017 2017 p19_05_bins_cov.sv run
run_case bins-2023 2023 p19_05_bins_cov.sv run
run_case tolerance-2017 2017 p19_05_tolerance_2023.sv reject
run_case tolerance-2023 2023 p19_05_tolerance_2023.sv run

echo "RESULT=$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
