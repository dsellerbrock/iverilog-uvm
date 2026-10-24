#!/usr/bin/env bash
set -euo pipefail

MODE=${1:?baseline or fixed}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CASE_DIR="$ROOT/evidence/m9-issue759-chandle-20261024"
OUT="$CASE_DIR/$MODE"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT/probes" "$OUT/collateral"
export PATH="$ROOT/local-install/bin:$PATH"
IVERILOG="$ROOT/local-install/bin/iverilog"
VVP="$ROOT/local-install/bin/vvp"
PROBE_SOURCE="$CASE_DIR/probes.sv"
SUMMARY="$OUT/summary.tsv"
printf 'probe\tedition\tcompile_rc\trun_rc\n' > "$SUMMARY"

run_probe() {
    local name=$1
    local top=$2
    local edition
    for edition in 2017 2023; do
        local base="$OUT/probes/$name-$edition"
        local compile_rc run_rc=NA
        set +e
        python3 "$ROOT/scripts/run_with_timeout.py" 120 -- \
            "$IVERILOG" "-g$edition" -s "$top" -o "$base.vvp" "$PROBE_SOURCE" \
            >"$base.compile.log" 2>&1
        compile_rc=$?
        set -e
        if [[ $compile_rc -eq 0 ]]; then
            set +e
            python3 "$ROOT/scripts/run_with_timeout.py" 120 -- \
                "$VVP" "$base.vvp" >"$base.run.log" 2>&1
            run_rc=$?
            set -e
        fi
        printf '%s\t%s\t%s\t%s\n' "$name" "$edition" "$compile_rc" "$run_rc" >> "$SUMMARY"
    done
}

for spec in \
    'rhs_chandle_to_int probe_rhs_chandle_to_int' \
    'rhs_chandle_to_bits probe_rhs_chandle_to_bits' \
    'rhs_chandle_to_longint probe_rhs_chandle_to_longint' \
    'rhs_chandle_to_real probe_rhs_chandle_to_real' \
    'rhs_chandle_to_string probe_rhs_chandle_to_string' \
    'rhs_chandle_class_property probe_rhs_chandle_class_property' \
    'rhs_chandle_class_method probe_rhs_chandle_class_method' \
    'compound_chandle_to_int probe_compound_chandle_to_int' \
    'valid_chandle_assignments probe_valid_chandle_assignments' \
    'valid_chandle_array_element probe_valid_chandle_array_element' \
    'valid_chandle_function probe_valid_chandle_function' \
    'valid_chandle_equality probe_valid_chandle_equality' \
    'valid_integral_assignment probe_valid_integral_assignment'; do
    read -r name top <<< "$spec"
    run_probe "$name" "$top"
done

legacy_tests=(
    ipsdownsel_real_idx ipsupsel_real_idx partsel_real_idx
    sv_class_static_fixed_array_container_element_read_fail
    sv_packed_part_select_variable_bound_fail sv_vif_array_runtime_index
    sv_vif_instance_runtime_index_extension
    sv_vif_instance_runtime_index_extension_2023
)
json_tests=(
    sv_chandle_assignment_incompatible_fail_2017
    sv_chandle_assignment_incompatible_fail_2023
    sv_chandle_nb_assignment_incompatible_fail_2017
    sv_chandle_nb_assignment_incompatible_fail_2023
    sv_class_static_fixed_array_container_element_read_fail
    sv_packed_part_select_variable_bound_fail
    sv_vif_instance_runtime_index_extension
    sv_vif_instance_runtime_index_extension_2023
)

for name in "${legacy_tests[@]}"; do
    awk -v name="$name" '$1 == name { print; n++ } END { exit n != 1 }' \
        "$ROOT/ivtest/regress-sv.list" > "$TMP/$name.legacy.list"
    set +e
    (cd "$ROOT/ivtest" && python3 "$ROOT/scripts/run_with_timeout.py" 120 -- \
        perl ./vvp_reg.pl "$TMP/$name.legacy.list") \
        >"$OUT/collateral/$name.legacy.runner.log" 2>&1
    rc=$?
    set -e
    cp "$ROOT/ivtest/log/$name.log" "$OUT/collateral/$name.legacy.log"
    printf 'legacy\t%s\t%s\n' "$name" "$rc" >> "$SUMMARY"
    [[ $rc -eq 0 ]] || exit "$rc"
done

for name in "${json_tests[@]}"; do
    awk -v name="$name" '$1 == name { print; n++ } END { exit n != 1 }' \
        "$ROOT/ivtest/regress-vvp.list" > "$TMP/$name.json.list"
    set +e
    (cd "$ROOT/ivtest" && python3 "$ROOT/scripts/run_with_timeout.py" 120 -- \
        python3 ./vvp_reg.py "$TMP/$name.json.list") \
        >"$OUT/collateral/$name.json.runner.log" 2>&1
    rc=$?
    set -e
    shopt -s nullglob
    logs=("$ROOT/ivtest/log/$name"-*.log)
    shopt -u nullglob
    for log in "${logs[@]}"; do
        base=${log##*/}
        suffix=${base#"$name"-}
        cp "$log" "$OUT/collateral/$name.json.$suffix"
    done
    printf 'json\t%s\t%s\n' "$name" "$rc" >> "$SUMMARY"
    [[ $rc -eq 0 ]] || exit "$rc"
done

printf 'mode=%s\nsource=%s\n' "$MODE" "${SOURCE_SHA:-unknown}" > "$OUT/run.meta"
