#!/usr/bin/env bash
set -u

OUT=evidence/m9-issue689-dynamic-options-20261026/attempt-07
mkdir -p "$OUT"

sh autoconf.sh >"$OUT/autoconf.log" 2>&1 || exit 1
./configure --enable-libveriuser --prefix="$PWD/local-install" \
  >"$OUT/configure.log" 2>&1 || exit 1
make -j3 >"$OUT/build.log" 2>&1 || exit 1
make install >"$OUT/install.log" 2>&1 || exit 1
export PATH="$PWD/local-install/bin:$PATH"

which iverilog >"$OUT/which-iverilog.txt"
iverilog -V >"$OUT/iverilog-V.txt" 2>&1

python3 scripts/run_with_timeout.py 120 -- iverilog -g2023 \
  -s sv_covergroup_item_goal_comment_extension_dynamic_2023 \
  -o "$OUT/dynamic-2023.vvp" \
  ivtest/ivltests/sv_covergroup_item_goal_comment_extension_dynamic_2023.v \
  >"$OUT/reducer-2023.compile.stdout" 2>"$OUT/reducer-2023.compile.stderr" || exit 1
python3 scripts/run_with_timeout.py 120 -- vvp "$OUT/dynamic-2023.vvp" \
  >"$OUT/reducer-2023.run.stdout" 2>"$OUT/reducer-2023.run.stderr" || exit 1
grep -q '^PASSED$' "$OUT/reducer-2023.run.stdout" || exit 1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0

cd ivtest || exit 1
focus_re='^sv_covergroup_(procedural_item_options|item_goal_comment)'
awk -v re="$focus_re" '$1 ~ re {print}' regress-sv.list >"$tmp/t0-legacy.list"
awk -v re="$focus_re" '$1 ~ re {print}' regress-vvp.list >"$tmp/t0-json.list"
perl ./vvp_reg.pl "$tmp/t0-legacy.list" >"../$OUT/t0-issue-legacy.log" 2>&1 || status=1
while IFS= read -r key; do
  awk -v key="$key" '$1 == key {print}' "$tmp/t0-json.list" >"$tmp/one-json.list"
  python3 ../scripts/run_with_timeout.py 120 -- python3 ./vvp_reg.py \
    "$tmp/one-json.list" >>"../$OUT/t0-issue-json.log" 2>&1 || status=1
done < <(awk '{print $1}' "$tmp/t0-json.list")

cd .. || exit 1
python3 scripts/run_with_timeout.py 3600 -- bash ci/run-smoke.sh \
  >"$OUT/t0-smoke.log" 2>&1 || status=1

cd ivtest || exit 1
T1_LEGACY=../evidence/m9-issue689-goal-comment-20261025/t1-legacy.list
T1_JSON=../evidence/m9-issue689-goal-comment-20261025/t1-json.list
perl ./vvp_reg.pl "$T1_LEGACY" >"../$OUT/t1-legacy.log" 2>&1 || status=1
while IFS= read -r key; do
  awk -v key="$key" '$1 == key {print}' "$T1_JSON" >"$tmp/one-json.list"
  python3 ../scripts/run_with_timeout.py 120 -- python3 ./vvp_reg.py \
    "$tmp/one-json.list" >>"../$OUT/t1-json.log" 2>&1 || status=1
done < <(awk '{print $1}' "$T1_JSON")

mkdir -p "../$OUT/diagnostics"
for log in log/sv_covergroup_item_goal_comment*-iverilog-stderr.log; do
  [ -f "$log" ] && cp "$log" "../$OUT/diagnostics/"
done

printf 'status=%s\nlegacy_t1=%s\njson_t1=%s\n' \
  "$status" "$(wc -l <"$T1_LEGACY")" "$(wc -l <"$T1_JSON")" \
  >"../$OUT/summary.txt"
exit "$status"
