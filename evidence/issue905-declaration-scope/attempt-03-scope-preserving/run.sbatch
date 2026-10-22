#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-905-t0-t1
#SBATCH --cpus-per-task=3
#SBATCH --mem=6G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue905-t0-t1-20261022-0008/logs/slurm-%j.out
set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue905-t0-t1-20261022-0008
ROOT=$RUN/source
LOGS=$RUN/logs
STATUS=0
mkdir -p "$ROOT"
tar -xzf "$RUN/source.tar.gz" -C "$ROOT"
cd "$ROOT" || exit 90
printf 'commit=4d5378a232cc27ad04d011a257eebad04ffbaa2f\n' | tee "$LOGS/metadata.txt"

run_step() {
  local label=$1 limit=$2
  shift 2
  echo "=== $label ==="
  if python3 "$ROOT/scripts/run_with_timeout.py" "$limit" -- "$@" > "$LOGS/$label.log" 2>&1; then
    echo "$label: PASS"
    tail -n 4 "$LOGS/$label.log"
    return 0
  else
    local rc=$?
    echo "$label: FAIL (exit $rc)"
    tail -n 60 "$LOGS/$label.log"
    STATUS=1
    return 1
  fi
}

if ! run_step autoconf 120 autoconf; then exit 10; fi
if ! run_step configure 600 ./configure --enable-libveriuser --prefix="$ROOT/local-install"; then exit 11; fi
if ! run_step build 1800 make -j3; then exit 12; fi
if ! run_step make-check 1800 make check; then exit 13; fi
if ! run_step install 300 make install; then exit 14; fi
export PATH="$ROOT/local-install/bin:$PATH"
"$ROOT/local-install/bin/iverilog" -V > "$LOGS/version.txt" 2>&1
cat "$LOGS/version.txt" | head -n 1

python3 - "$ROOT" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
ivtest = root / "ivtest"
t0 = {
    "sv_default_argument_declaration_scope",
    "sv_default_argument_declaration_scope_2023",
    "sv_default_argument_declaration_scope_missing",
    "sv_default_argument_declaration_scope_missing_2023",
}
t1 = t0 | {
    "sv_class_method_default1", "sv_class_method_default2",
    "sv_class_constructor_default", "sv_default_formal_contexts",
    "sv_automatic_integral_default_events", "sv_automatic_integral_default_events_2023",
    "sv_automatic_integral_default_recursive", "sv_automatic_integral_default_recursive_2023",
    "sv_automatic_boolean_default_chain", "sv_automatic_boolean_default_chain_2023",
    "sv_class_parenless_defaulted_method", "sv_class_parenless_defaulted_method_2023",
    "sv_method_default_argument_this", "sv_method_default_argument_this_2023",
    "sv_constraint_function_named_default_arguments",
    "sv_constraint_function_named_default_arguments_2023",
}
t1_json = t0 | {
    "sv_automatic_integral_default_events", "sv_automatic_integral_default_events_2023",
    "sv_automatic_integral_default_recursive", "sv_automatic_integral_default_recursive_2023",
    "sv_automatic_boolean_default_chain", "sv_automatic_boolean_default_chain_2023",
    "sv_class_parenless_defaulted_method", "sv_class_parenless_defaulted_method_2023",
    "sv_method_default_argument_this", "sv_method_default_argument_this_2023",
    "sv_constraint_function_named_default_arguments",
    "sv_constraint_function_named_default_arguments_2023",
    "sv_class_method_noarg_string_concat_2017", "sv_class_method_noarg_string_concat_2023",
}
def select(master, names, output):
    found = {}
    for line in (ivtest / master).read_text().splitlines():
        fields = line.split()
        if fields and fields[0] in names:
            found[fields[0]] = line
    missing = names - found.keys()
    if missing:
        raise SystemExit(f"missing test-list entries in {master}: {sorted(missing)}")
    (ivtest / output).write_text("\n".join(found[name] for name in sorted(names)) + "\n")
select("regress-sv.list", t0, "issue905-t0-legacy.list")
select("regress-sv.list", t1, "issue905-t1-legacy.list")
select("regress-vvp.list", t0, "issue905-t0-json.list")
select("regress-vvp.list", t1_json, "issue905-t1-json.list")
PY

run_step T0-issue-legacy 600 bash -c 'cd "$1" && perl ./vvp_reg.pl issue905-t0-legacy.list' _ "$ROOT/ivtest"
run_json_manifest() {
  local manifest=$1 label=$2 output="$LOGS/$2.log" name json rc
  : > "$output"
  while read -r name json; do
    [ -z "$name" ] && continue
    echo "=== $name ===" >> "$output"
    printf '%s %s\n' "$name" "$json" > "$ROOT/ivtest/issue905-one-json.list"
    (cd "$ROOT/ivtest" && python3 "$ROOT/scripts/run_with_timeout.py" 60 -- python3 ./vvp_reg.py issue905-one-json.list) >> "$output" 2>&1
    rc=$?
    echo "$name: exit=$rc" >> "$output"
    if [ "$rc" -ne 0 ]; then STATUS=1; fi
  done < "$ROOT/ivtest/$manifest"
  if [ "$STATUS" -eq 0 ]; then echo "$label: PASS"; else echo "$label: FAIL"; tail -n 60 "$output"; fi
}
run_json_manifest issue905-t0-json.list T0-issue-json

if ! run_step T0-smoke 3600 ./ci/run-smoke.sh; then echo 'smoke failures recorded; continuing T1'; fi

run_step T1-related-legacy 900 bash -c 'cd "$1" && perl ./vvp_reg.pl issue905-t1-legacy.list' _ "$ROOT/ivtest"
run_json_manifest issue905-t1-json.list T1-related-json
printf 'T0_T1_STATUS=%s\n' "$STATUS" | tee "$LOGS/result.txt"
exit "$STATUS"
