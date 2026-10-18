#!/usr/bin/env bash
#SBATCH --job-name=a3-1800-c19b
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19b-20261017-01/logs/%x-%j.out
set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19b-20261017-01
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/combined.txt") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

echo "SOURCE_COMMIT=16404e84d"
echo "SOURCE_DIRTY=uncommitted c19b probe sources"
hostname; uname -a; date -Is; nproc
"$TOOL/bin/iverilog" -V > "$RESULTS/iverilog-version.log" 2>&1
sed -n '1,3p' "$RESULTS/iverilog-version.log"
sha256sum "$TOOL/bin/iverilog" "$TOOL/bin/vvp" "$RUN/input"/*.sv "$RUN/input/neg"/*.sv

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
    timeout --signal=TERM --kill-after=5 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$image" "$RUN/input/$source" >"$compile_log" 2>&1
    compile_rc=$?
    set -e
    echo "compile_rc=$compile_rc"
    cat "$compile_log"
    if [[ $expected == reject ]]; then
        if [[ $compile_rc -eq 0 ]] || grep -qi 'No top level modules' "$compile_log"; then
            echo UNEXPECTED_ACCEPTANCE_OR_ROOT; status=1
        else
            echo EXPECTED_REJECTION
        fi
        return
    fi
    if [[ $compile_rc -ne 0 ]]; then status=1; return; fi
    set +e
    timeout --signal=TERM --kill-after=5 30 "$TOOL/bin/vvp" "$image" >"$run_log" 2>&1
    run_rc=$?
    set -e
    echo "run_rc=$run_rc"
    cat "$run_log"
    if [[ $run_rc -ne 0 ]] || grep -q '^FAIL ' "$run_log"; then
        if [[ $label == cg-* ]]; then
            unexpected=$(grep '^FAIL ' "$run_log" | grep -Ev '^FAIL 19\.8\.(cp_inst_total_2|cg_inst_total_5|type_cp_total_6|type_cg_total_16)$' || true)
            if [[ -n $unexpected ]]; then status=1; fi
            grep -q '^DONE fails=' "$run_log" || status=1
        else
            status=1
        fi
    fi
    if [[ $label == cg-* ]]; then
        grep -q '^PASS 19\.3\.ref_arg_tracks_value$' "$run_log" || status=1
        grep -q '^PASS 19\.3\.input_arg_sizes_bins$' "$run_log" || status=1
        grep -q '^PASS 19\.3\.instances_independent$' "$run_log" || status=1
        grep -q '^PASS 19\.3\.clocking_event_samples$' "$run_log" || status=1
        grep -q '^PASS 19\.8\.1\.sample_with_args$' "$run_log" || status=1
        grep -q '^PASS 19\.8\.stop_blocks_sampling$' "$run_log" || status=1
        grep -q '^PASS 19\.8\.start_resumes$' "$run_log" || status=1
        grep -q '^PASS 19\.8\.set_inst_name$' "$run_log" || status=1
        grep -q '^PASS 19\.4\.embedded_cg_event_on_local_member$' "$run_log" || status=1
        grep -q '^PASS 19\.4\.embedded_cg_second_sample$' "$run_log" || status=1
    elif [[ $label == block-* ]]; then
        grep -q '^PASS 19\.3\.block_event_end' "$run_log" || status=1
    fi
}

for edition in 2017 2023; do
    run_case "cg-$edition" "$edition" p19_03_08_cg.sv run
    run_case "block-$edition" "$edition" p19_03_block_event.sv run
    run_case "neg-output-$edition" "$edition" neg/n19_03_output_formal.sv reject
    run_case "neg-assign-$edition" "$edition" neg/n19_04_assign_outside_new.sv reject
    run_case "neg-extends-$edition" "$edition" neg/n19_03_extends_outside_class.sv reject
done

echo "RESULT=$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
