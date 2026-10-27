#!/usr/bin/env bash
set -uo pipefail
SRC=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue905-default-arg-scope-20261021
LOG=$PWD/evidence/issue905-declaration-scope/attempt-07-local-a139-native-deps
BLD=$(mktemp -d /tmp/a3-issue905-local-a139.XXXXXX)
SOURCE_DIR=$BLD/source
TESTROOT=$BLD/testroot
printf 'commit=a139d2eb3b7ac16530578ce3cf47a1b28576b906\n' > "$LOG/metadata.txt"
printf 'build_dir=%s\nsource_dir=%s\n' "$BLD" "$SOURCE_DIR" >> "$LOG/metadata.txt"
printf 'host=macOS localrun; threads=3; memory_budget~7GiB\n' >> "$LOG/metadata.txt"
STATUS=0
run_step() {
  local label=$1 limit=$2; shift 2
  echo "=== $label ==="
  if python3 "$SRC/scripts/run_with_timeout.py" "$limit" -- "$@" > "$LOG/$label.log" 2>&1; then
    echo "$label: PASS"; tail -n 5 "$LOG/$label.log"
  else
    rc=$?; echo "$label: FAIL (exit $rc)"; tail -n 45 "$LOG/$label.log"; STATUS=1
  fi
}
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include ${CPPFLAGS:-}"
export LDFLAGS="-Wl,-all_load -L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib ${LDFLAGS:-}"
cd "$BLD" || exit 90
mkdir -p "$SOURCE_DIR"
run_step stage-source 1200 bash -c 'git -C "$1" archive --format=tar HEAD | tar -xf - -C "$2"' _ "$SRC" "$SOURCE_DIR"
[ "$STATUS" -eq 0 ] || exit "$STATUS"
run_step autoconf 120 bash -c 'cd "$1" && autoconf' _ "$SOURCE_DIR"
[ "$STATUS" -eq 0 ] || exit "$STATUS"
run_step configure 900 "$SOURCE_DIR/configure" --enable-libveriuser --prefix="$BLD/install"
[ "$STATUS" -eq 0 ] || exit "$STATUS"
run_step build 2400 make -j3
[ "$STATUS" -eq 0 ] || exit "$STATUS"
run_step install 600 make install
[ "$STATUS" -eq 0 ] || exit "$STATUS"
"$BLD/install/bin/iverilog" -V > "$LOG/version.txt" 2>&1
mkdir -p "$TESTROOT"
cp -a "$SOURCE_DIR/ivtest" "$TESTROOT/ivtest"
cp -a "$SOURCE_DIR/tests" "$TESTROOT/tests"
cp -a "$SOURCE_DIR/scripts" "$TESTROOT/scripts"
export PATH="$BLD/install/bin:$PATH"
python3 - "$TESTROOT" "$BLD" <<'PY'
import pathlib, sys
root, bld = map(pathlib.Path, sys.argv[1:])
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
t1_json = t1 | {
  "sv_class_method_noarg_string_concat_2017",
  "sv_class_method_noarg_string_concat_2023",
}
def select(master, names, output):
  found = {}
  for line in (ivtest / master).read_text().splitlines():
    fields = line.split()
    if fields and fields[0] in names:
      found[fields[0]] = line
  missing = names - found.keys()
  if missing:
    raise SystemExit(f"missing test entries in {master}: {sorted(missing)}")
  (bld / output).write_text("\n".join(found[n] for n in sorted(names)) + "\n")
select("regress-sv.list", t1, "issue905-t1-legacy.list")
select("regress-vvp.list", t1_json, "issue905-t1-json.list")
PY
cd "$TESTROOT/ivtest" || exit 91
run_step T1-related-legacy 1200 perl ./vvp_reg.pl "$BLD/issue905-t1-legacy.list"
cp -a log "$BLD/T1-legacy-test-logs"
run_json_manifest() {
  local manifest=$1 label=$2 line name json rc
  : > "$LOG/$label.log"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    name=${line%% *}; json=${line#* }
    printf '%s %s\n' "$name" "$json" > "$BLD/one-json.list"
    echo "=== $name ===" >> "$LOG/$label.log"
    python3 "$TESTROOT/scripts/run_with_timeout.py" 60 -- python3 ./vvp_reg.py "$BLD/one-json.list" >> "$LOG/$label.log" 2>&1
    rc=$?
    echo "$name: exit=$rc" >> "$LOG/$label.log"
    [ "$rc" -eq 0 ] || STATUS=1
  done < "$BLD/$manifest"
  if [ "$STATUS" -eq 0 ]; then echo "$label: PASS"; else echo "$label: FAIL"; tail -n 60 "$LOG/$label.log"; fi
}
run_json_manifest issue905-t1-json.list T1-related-json
cp -a log "$BLD/T1-json-test-logs"
echo "T1_STATUS=$STATUS" | tee "$LOG/result.txt"
exit "$STATUS"
