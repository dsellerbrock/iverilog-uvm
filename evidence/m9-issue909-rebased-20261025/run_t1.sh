#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
RESULTS=${RESULTS_DIR:-$ROOT/evidence/m9-issue909-rebased-20261025/results}
mkdir -p "$RESULTS"
printf 'source_sha=%s\n' "${SOURCE_SHA:-unknown}" > "$RESULTS/summary.txt"
autoconf > "$RESULTS/autoconf.log" 2>&1
./configure --prefix="$ROOT/local-install" > "$RESULTS/configure.log" 2>&1
make -j3 > "$RESULTS/build.log" 2>&1
make install > "$RESULTS/install.log" 2>&1
export PATH="$ROOT/local-install/bin:$PATH"
: > "$RESULTS/reproducer.tsv"
for edition in 2017 2023; do
  rc=0
  python3 "$ROOT/scripts/run_with_timeout.py" 120 -- \
    iverilog "-g$edition" -s sv_output_clockvar_variable_drivers_fail \
      -o "$RESULTS/repro-$edition.vvp" \
      "$ROOT/ivtest/ivltests/sv_output_clockvar_variable_drivers_fail.v" \
      >"$RESULTS/repro-$edition.log" 2>&1 || rc=$?
  if [[ $rc -eq 0 || $rc -ge 124 ]] || ! grep -q 'associated with an output clockvar' "$RESULTS/repro-$edition.log"; then
    printf '%s\tFAIL\t%s\n' "$edition" "$rc" >> "$RESULTS/reproducer.tsv"
    exit 1
  fi
  printf '%s\tPASS\t%s\n' "$edition" "$rc" >> "$RESULTS/reproducer.tsv"
done
cd "$ROOT/ivtest"
legacy_re='(sv_clocking_fixed_array_output_decl|sv_clocking_output_continuous_(alias_overlap|declaration_only|disjoint|pending_overlap|same_scope_overlap|static_overlap|virtual_overlap)|sv_output_clockvar_variable_drivers_fail|sv_output_clockvar_variable_driver_controls)'
json_re='(sv_clocking_fixed_array_output_decl_(2017|2023)|sv_clocking_output_continuous_(alias_overlap|declaration_only|disjoint|disjoint_first_receiver|pending_overlap|same_scope_overlap|static_overlap|static_overlap_unsafe|virtual_overlap|virtual_overlap_unsafe)_(2017|2023)|sv_output_clockvar_variable_drivers_fail_(2017|2023)|sv_output_clockvar_variable_driver_controls_(2017|2023)|sv_clocking_output_net_driver_(2017|2023))'
grep -E "^${legacy_re}[[:space:]]" regress-sv.list > "$RESULTS/t1-legacy.list"
grep -E "^${json_re}[[:space:]]" regress-vvp.list > "$RESULTS/t1-json.list"
[[ $(wc -l < "$RESULTS/t1-legacy.list" | tr -d ' ') = 10 ]]
[[ $(wc -l < "$RESULTS/t1-json.list" | tr -d ' ') = 28 ]]
: > "$RESULTS/tests.tsv"
run_one() {
  local label=$1; shift
  local rc=0
  python3 "$ROOT/scripts/run_with_timeout.py" 300 -- "$@" > "$RESULTS/$label.log" 2>&1 || rc=$?
  printf '%s\t%s\n' "$label" "$rc" >> "$RESULTS/tests.tsv"
  [[ $rc -eq 0 ]]
}
while IFS= read -r row; do
  name=${row%%[[:space:]]*}
  printf '%s\n' "$row" > "$RESULTS/one.list"
  run_one "legacy-$name" perl ./vvp_reg.pl "$RESULTS/one.list"
done < "$RESULTS/t1-legacy.list"
while IFS= read -r row; do
  name=${row%%[[:space:]]*}
  printf '%s\n' "$row" > "$RESULTS/one.list"
  run_one "json-$name" python3 ./vvp_reg.py "$RESULTS/one.list"
done < "$RESULTS/t1-json.list"
printf 'legacy=%s json=%s\n' \
  "$(wc -l < "$RESULTS/t1-legacy.list" | tr -d ' ')" \
  "$(wc -l < "$RESULTS/t1-json.list" | tr -d ' ')" >> "$RESULTS/summary.txt"
