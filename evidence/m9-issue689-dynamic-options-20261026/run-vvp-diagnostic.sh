#!/usr/bin/env bash
set -euo pipefail

out=evidence/m9-issue689-dynamic-options-20261026/attempt-03
mkdir -p "$out"
ulimit -c 0
autoconf
./configure --enable-libveriuser --prefix="$PWD/local-install-diagnostic-03"
make -j3
make install
export PATH="$PWD/local-install-diagnostic-03/bin:$PATH"

python3 scripts/run_with_timeout.py 120 -- iverilog -g2023 \
  -s sv_covergroup_item_goal_comment_extension_dynamic_2023 \
  -o "$out/dynamic.vvp" \
  ivtest/ivltests/sv_covergroup_item_goal_comment_extension_dynamic_2023.v \
  >"$out/compile.stdout" 2>"$out/compile.stderr"

set +e
python3 scripts/run_with_timeout.py 120 -- vvp "$out/dynamic.vvp" \
  >"$out/run.stdout" 2>"$out/run.stderr"
run_rc=$?
set -e
printf 'compile=0\nrun=%s\n' "$run_rc" > "$out/result.txt"
