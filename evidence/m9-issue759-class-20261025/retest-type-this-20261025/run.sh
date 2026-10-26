#!/usr/bin/env bash
set -u

OUT=evidence/m9-issue759-class-20261025/retest-type-this-20261025
mkdir -p "$OUT"

./autoconf.sh >"$OUT/autoconf.log" 2>&1 || exit 1
./configure --prefix="$PWD/local-install" >"$OUT/configure.log" 2>&1 || exit 1
make -j2 >"$OUT/build.log" 2>&1 || exit 1
make install >"$OUT/install.log" 2>&1 || exit 1

PATH="$PWD/local-install/bin:$PATH"
export PATH

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0

cd ivtest
issue_re='^sv_class_handle_(to_integral_assignment_fail|compound_to_integral_assignment_fail|clockvar_to_integral_assignment_fail|initializer_to_integral_assignment_fail|property_to_integral_assignment_fail|specialization_to_integral_fail|generic_template_new)'
awk -v re="$issue_re" '$1 ~ re {print}' regress-sv.list >"$tmp/issue-legacy.list"
awk -v re="$issue_re" '$1 ~ re {print}' regress-vvp.list >"$tmp/issue-json.list"

perl ./vvp_reg.pl "$tmp/issue-legacy.list" >"../$OUT/t0-issue-legacy.log" 2>&1 || status=1
while IFS= read -r key; do
    awk -v key="$key" '$1 == key {print}' "$tmp/issue-json.list" >"$tmp/one-json.list"
    python3 ../scripts/run_with_timeout.py 120 -- python3 ./vvp_reg.py "$tmp/one-json.list" >>"../$OUT/t0-issue-json.log" 2>&1 || status=1
done < <(awk 'NF == 2 {print $1}' "$tmp/issue-json.list")

cd ..
python3 scripts/run_with_timeout.py 3600 -- bash ci/run-smoke.sh >"$OUT/t0-smoke.log" 2>&1 || status=1

cd ivtest
T1_LEGACY=../evidence/m9-issue759-class-20261025/t1-legacy.list
T1_JSON=../evidence/m9-issue759-class-20261025/t1-json.list
perl ./vvp_reg.pl "$T1_LEGACY" >"../$OUT/t1-legacy.log" 2>&1 || status=1
while IFS= read -r key; do
    awk -v key="$key" '$1 == key {print}' "$T1_JSON" >"$tmp/one-json.list"
    python3 ../scripts/run_with_timeout.py 120 -- python3 ./vvp_reg.py "$tmp/one-json.list" >>"../$OUT/t1-json.log" 2>&1 || status=1
done < <(awk 'NF == 2 {print $1}' "$T1_JSON")

printf 'status=%s\nlegacy_t1=%s\njson_t1=%s\n' \
    "$status" "$(wc -l <"$T1_LEGACY")" "$(wc -l <"$T1_JSON")" \
    >"../$OUT/summary.txt"
exit "$status"
