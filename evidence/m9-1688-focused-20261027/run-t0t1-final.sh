#!/usr/bin/env bash
set -u
repo=$PWD
out="$repo/evidence/m9-1688-focused-20261027/final-gate"
mkdir -p "$out"
status=0
./autoconf.sh >"$out/autoconf.log" 2>&1 || exit 1
./configure --prefix="$repo/local-install" >"$out/configure.log" 2>&1 || exit 1
make -j3 >"$out/build.log" 2>&1 || exit 1
make install >"$out/install.log" 2>&1 || exit 1
export PATH="$repo/local-install/bin:$PATH"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$repo/ivtest" || exit 2
focus_re='^sv_covergroup_(procedural_item_options|item_goal_comment)'
awk -v re="$focus_re" '$1 ~ re {print}' regress-sv.list >"$out/t0-legacy.list"
awk -v re="$focus_re" '$1 ~ re {print}' regress-vvp.list >"$out/t0-json.list"
perl ./vvp_reg.pl "$out/t0-legacy.list" >"$out/t0-legacy.log" 2>&1 || status=1
while IFS= read -r key; do
  awk -v key="$key" '$1 == key {print}' "$out/t0-json.list" >"$tmp/one-json.list"
  python3 ../scripts/run_with_timeout.py 120 -- python3 ./vvp_reg.py \
    "$tmp/one-json.list" >>"$out/t0-json.log" 2>&1 || status=1
done < <(awk '{print $1}' "$out/t0-json.list")
cd "$repo" || exit 2
python3 scripts/run_with_timeout.py 3600 -- bash ci/run-smoke.sh >"$out/t0-smoke.log" 2>&1 || status=1
cd "$repo/ivtest" || exit 2
T1_LEGACY="$repo/evidence/m9-1688-focused-20261027/t1-legacy-final.list"
T1_JSON="$repo/evidence/m9-1688-focused-20261027/t1-json-final.list"
perl ./vvp_reg.pl "$T1_LEGACY" >"$out/t1-legacy.log" 2>&1 || status=1
while IFS= read -r key; do
  awk -v key="$key" '$1 == key {print}' "$T1_JSON" >"$tmp/one-json.list"
  python3 ../scripts/run_with_timeout.py 120 -- python3 ./vvp_reg.py \
    "$tmp/one-json.list" >>"$out/t1-json.log" 2>&1 || status=1
done < <(awk '{print $1}' "$T1_JSON")
printf 'status=%s\nt0_legacy=%s\nt0_json=%s\nt1_legacy=%s\nt1_json=%s\n' \
  "$status" "$(wc -l <"$out/t0-legacy.list")" "$(wc -l <"$out/t0-json.list")" \
  "$(wc -l <"$T1_LEGACY")" "$(wc -l <"$T1_JSON")" >"$out/summary.txt"
exit "$status"
