#!/usr/bin/env bash
set -euo pipefail

out=evidence/m9-issue689-dynamic-options-20261026/attempt-01
mkdir -p "$out"
autoconf
./configure --enable-libveriuser --prefix="$PWD/local-install-repro"
make -j3
make install
export PATH="$PWD/local-install-repro/bin:$PATH"

if python3 scripts/run_with_timeout.py 120 -- iverilog -g2023 \
    -s sv_covergroup_item_goal_comment_extension_dynamic_2023 \
    -o "$out/dynamic-2023.vvp" \
    ivtest/ivltests/sv_covergroup_item_goal_comment_extension_dynamic_2023.v \
    >"$out/dynamic-2023.stdout" 2>"$out/dynamic-2023.stderr"; then
  echo "ERROR: expected PR-head false rejection was not reproduced" >&2
  exit 1
fi
if ! grep -q "constructor-dependent coverage option" "$out/dynamic-2023.stderr"; then
  cat "$out/dynamic-2023.stderr" >&2
  echo "ERROR: compile failed for a reason other than the reported rejection" >&2
  exit 1
fi

if python3 scripts/run_with_timeout.py 120 -- iverilog -g2023 \
    -s sv_covergroup_item_goal_comment_extension_2023 \
    -o "$out/control.vvp" \
    ivtest/ivltests/sv_covergroup_item_goal_comment_extension_2023.v \
    >"$out/control-compile.stdout" 2>"$out/control-compile.stderr"; then
  python3 scripts/run_with_timeout.py 120 -- vvp "$out/control.vvp" \
    >"$out/control-run.stdout" 2>"$out/control-run.stderr"
else
  cat "$out/control-compile.stderr" >&2
  echo "ERROR: existing constant-option positive control failed" >&2
  exit 1
fi
grep -q '^PASSED$' "$out/control-run.stdout"

printf 'repro=confirmed: standard-valid 2023 derived option expressions rejected\n' > "$out/result.txt"
printf 'control=passed: constant 2023 derived options\n' >> "$out/result.txt"
