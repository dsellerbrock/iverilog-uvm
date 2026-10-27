#!/usr/bin/env bash
set -uo pipefail
SRC=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue905-default-arg-scope-20261021
BLD=/tmp/a3-issue905-local-a139.csib2Q
PREVIOUS_SOURCE=$BLD/source
RUN=$(mktemp -d /tmp/a3-issue905-t1-b24.XXXXXX)
TESTROOT=$RUN/testroot
LOG=$PWD/evidence/issue905-declaration-scope/attempt-08-local-t1-b24
printf 'head=b24b06d67\ncompiler_source_commit=a139d2eb3b7ac16530578ce3cf47a1b28576b906\nhost=macOS localrun; reused existing local build; memory budget~7GiB\n' > "$LOG/metadata.txt"
printf 'testroot=%s\nbuild_dir=%s\n' "$TESTROOT" "$BLD" >> "$LOG/metadata.txt"
mkdir -p "$TESTROOT"
cp -a "$PREVIOUS_SOURCE/ivtest" "$TESTROOT/ivtest"
cp -a "$PREVIOUS_SOURCE/tests" "$TESTROOT/tests"
cp -a "$PREVIOUS_SOURCE/scripts" "$TESTROOT/scripts"
cp "$SRC/ivtest/regress-sv.list" "$TESTROOT/ivtest/regress-sv.list"
export PATH="$BLD/install/bin:/opt/homebrew/opt/bison/bin:$PATH"
python3 - "$TESTROOT" "$RUN" <<'PY'
import pathlib, sys
root, run = map(pathlib.Path, sys.argv[1:])
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
    raise SystemExit(f"missing tests in {master}: {sorted(missing)}")
  (run / output).write_text("\n".join(found[n] for n in sorted(names)) + "\n")
select("regress-sv.list", t0, "t0-legacy.list")
select("regress-sv.list", t1, "t1-legacy.list")
select("regress-vvp.list", t0, "t0-json.list")
select("regress-vvp.list", t1_json, "t1-json.list")
PY
STATUS=0
run_step() {
  local label=$1 limit=$2; shift 2
  echo "=== $label ==="
  if python3 "$TESTROOT/scripts/run_with_timeout.py" "$limit" -- "$@" > "$LOG/$label.log" 2>&1; then
    echo "$label: PASS"; tail -n 6 "$LOG/$label.log"
  else
    rc=$?; echo "$label: FAIL (exit $rc)"; tail -n 50 "$LOG/$label.log"; STATUS=1
  fi
}
cd "$TESTROOT/ivtest" || exit 91
run_step T0-issue-legacy 600 perl ./vvp_reg.pl "$RUN/t0-legacy.list"
run_step T0-issue-json 600 python3 ./vvp_reg.py "$RUN/t0-json.list"
run_step T1-related-legacy 1200 perl ./vvp_reg.pl "$RUN/t1-legacy.list"
cp -a log "$RUN/T1-legacy-test-logs"
run_json_manifest() {
  local manifest=$1 label=$2 line name json rc
  : > "$LOG/$label.log"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    name=${line%% *}; json=${line#* }
    printf '%s %s\n' "$name" "$json" > "$RUN/one-json.list"
    echo "=== $name ===" >> "$LOG/$label.log"
    python3 "$TESTROOT/scripts/run_with_timeout.py" 60 -- python3 ./vvp_reg.py "$RUN/one-json.list" >> "$LOG/$label.log" 2>&1
    rc=$?
    echo "$name: exit=$rc" >> "$LOG/$label.log"
    [ "$rc" -eq 0 ] || STATUS=1
  done < "$RUN/$manifest"
  if [ "$STATUS" -eq 0 ]; then echo "$label: PASS"; else echo "$label: FAIL"; tail -n 60 "$LOG/$label.log"; fi
}
run_json_manifest t1-json.list T1-related-json
cp -a log "$RUN/T1-json-test-logs"
echo "T0_T1_STATUS=$STATUS" | tee "$LOG/result.txt"
exit "$STATUS"
