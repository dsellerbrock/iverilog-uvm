#!/usr/bin/env bash
set -euo pipefail

MODE=${1:?baseline or fixed}
IVERILOG=${2:?iverilog path}
VVP=${3:?vvp path}
SOURCE_SHA=${4:?compiler source commit}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CASE_DIR="$ROOT/evidence/m9-issue759-chandle-20261024"
OUT="$CASE_DIR/$MODE/edge-probes"
SOURCE="$CASE_DIR/edge-probes.sv"
mkdir -p "$OUT"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
printf 'probe\tedition\tcompile_rc\trun_rc\n' > "$OUT/summary.tsv"

for spec in \
    'nb_chandle_to_int probe_nb_chandle_to_int' \
    'valid_nb_chandle_copy probe_valid_nb_chandle_copy' \
    'valid_nb_chandle_null probe_valid_nb_chandle_null' \
    'chandle_continuous probe_chandle_continuous' \
    'chandle_initializer probe_chandle_initializer' \
    'chandle_function_argument probe_chandle_function_argument' \
    'chandle_function_return probe_chandle_function_return' \
    'chandle_event_control probe_chandle_event_control' \
    'chandle_procedural_assign probe_chandle_procedural_assign' \
    'chandle_force probe_chandle_force'; do
    read -r name top <<< "$spec"
    for edition in 2017 2023; do
        base="$OUT/$name-$edition"
        image="$TMP/$name-$edition.vvp"
        set +e
        python3 "$ROOT/scripts/run_with_timeout.py" 120 -- \
            "$IVERILOG" "-g$edition" -s "$top" -o "$image" "$SOURCE" \
            >"$base.compile.log" 2>&1
        compile_rc=$?
        run_rc=NA
        if [[ $compile_rc -eq 0 ]]; then
            python3 "$ROOT/scripts/run_with_timeout.py" 120 -- \
                "$VVP" "$image" >"$base.run.log" 2>&1
            run_rc=$?
        fi
        set -e
        printf '%s\t%s\t%s\t%s\n' "$name" "$edition" "$compile_rc" "$run_rc" \
            >> "$OUT/summary.tsv"
    done
done

"$IVERILOG" -V > "$OUT/iverilog-version.txt" 2>&1
shasum -a 256 "$IVERILOG" "$VVP" > "$OUT/toolchain.sha256"
printf 'mode=%s\ncompiler_source=%s\nhost=Mac\n' "$MODE" "$SOURCE_SHA" \
    > "$OUT/run.meta"
