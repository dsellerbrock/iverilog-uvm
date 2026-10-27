#!/usr/bin/env bash
set -uo pipefail

ROOT=$(pwd)
OUT="$ROOT/evidence/issue905-declaration-scope/attempt-09-current-main/results"
PREFIX="$ROOT/local-install"
mkdir -p "$OUT/logs"
printf 'source_commit=recorded by slurm-run\nhost=Slurm DAN-DESKTOP\ncpus=3\nmem=8G\n' > "$OUT/metadata.txt"

autoconf || exit 2
./configure --enable-libveriuser --prefix="$PREFIX" > "$OUT/configure.log" 2>&1 || { tail -100 "$OUT/configure.log"; exit 2; }
make -j3 > "$OUT/build.log" 2>&1 || { tail -100 "$OUT/build.log"; exit 2; }
make install > "$OUT/install.log" 2>&1 || { tail -100 "$OUT/install.log"; exit 2; }
export PATH="$PREFIX/bin:$PATH"

python3 - "$ROOT" "$OUT" <<'PY'
from pathlib import Path
import sys

root, out = map(Path, sys.argv[1:])
ivtest = root / "ivtest"

def names(path):
    return {
        line.split()[0]
        for line in path.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }

def select(master, wanted, target):
    found = {}
    for line in master.read_text().splitlines():
        fields = line.split()
        if fields and fields[0] in wanted:
            found[fields[0]] = line
    missing = wanted - found.keys()
    if missing:
        raise SystemExit(f"missing tests in {master}: {sorted(missing)}")
    target.write_text("\n".join(found[name] for name in sorted(wanted)) + "\n")

def select_json_files(wanted, target):
    rows = []
    missing = []
    for name in sorted(wanted):
        path = ivtest / "vvp_tests" / f"{name}.json"
        if path.is_file():
            rows.append(f"{name} vvp_tests/{path.name}")
        else:
            missing.append(name)
    if missing:
        raise SystemExit(f"missing JSON files: {missing}")
    target.write_text("\n".join(rows) + "\n")

t0 = {
    "sv_default_argument_declaration_scope",
    "sv_default_argument_declaration_scope_2023",
    "sv_default_argument_declaration_scope_missing",
    "sv_default_argument_declaration_scope_missing_2023",
}
t1_legacy = t0 | {
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
select(ivtest / "regress-sv.list", names(root / "ci/smoke-tests.txt"), out / "smoke.list")
select(ivtest / "regress-sv.list", t0, out / "t0-legacy.list")
select(ivtest / "regress-vvp.list", t0, out / "t0-json.list")
select(ivtest / "regress-sv.list", t1_legacy, out / "t1-legacy.list")
select_json_files(t1_json, out / "t1-json.list")
PY
rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

status=0
run_manifest() {
    local kind=$1 manifest=$2 label=$3 row name logfile rc
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        name=${row%% *}
        logfile="$OUT/logs/$label-$name.log"
        printf '%s\n' "$row" > "$OUT/one.list"
        printf '%s ' "$label/$name"
        if [ "$kind" = legacy ]; then
            python3 "$ROOT/scripts/run_with_timeout.py" 120 -- perl ./vvp_reg.pl "$OUT/one.list" > "$logfile" 2>&1
        else
            python3 "$ROOT/scripts/run_with_timeout.py" 120 -- python3 ./vvp_reg.py "$OUT/one.list" > "$logfile" 2>&1
        fi
        rc=$?
        if [ "$rc" -eq 0 ]; then
            echo PASS
        else
            echo "FAIL ($rc)"
            tail -40 "$logfile"
            status=1
        fi
    done < "$manifest"
}

cd "$ROOT/ivtest" || exit 2
run_manifest legacy "$OUT/smoke.list" smoke
run_manifest legacy "$OUT/t0-legacy.list" t0-legacy
run_manifest json "$OUT/t0-json.list" t0-json
run_manifest legacy "$OUT/t1-legacy.list" t1-legacy
run_manifest json "$OUT/t1-json.list" t1-json

printf 'T0_T1_STATUS=%s\n' "$status" | tee "$OUT/result.txt"
exit "$status"
