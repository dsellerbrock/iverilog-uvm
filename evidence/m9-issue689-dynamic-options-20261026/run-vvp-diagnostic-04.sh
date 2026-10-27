#!/usr/bin/env bash
set -euo pipefail

out=evidence/m9-issue689-dynamic-options-20261026/attempt-04
mkdir -p "$out"
ulimit -c 0
autoconf
./configure --enable-libveriuser --prefix="$PWD/local-install-diagnostic-04"
make -j3
make install
export PATH="$PWD/local-install-diagnostic-04/bin:$PATH"

which iverilog >"$out/which-iverilog.txt"
iverilog -V >"$out/iverilog-V.txt" 2>&1

compile_2023=0
if python3 scripts/run_with_timeout.py 120 -- iverilog -g2023 \
    -s sv_covergroup_item_goal_comment_extension_dynamic_2023 \
    -o "$out/dynamic-2023.vvp" \
    ivtest/ivltests/sv_covergroup_item_goal_comment_extension_dynamic_2023.v \
    >"$out/compile-2023.stdout" 2>"$out/compile-2023.stderr"; then
  :
else
  compile_2023=$?
fi

run_2023=skipped
if [ "$compile_2023" -eq 0 ]; then
  run_2023=0
  if python3 scripts/run_with_timeout.py 120 -- vvp "$out/dynamic-2023.vvp" \
      >"$out/run-2023.stdout" 2>"$out/run-2023.stderr"; then
    :
  else
    run_2023=$?
  fi
fi

compile_2017=0
if python3 scripts/run_with_timeout.py 120 -- iverilog -g2017 \
    -s sv_covergroup_item_goal_comment_extension_dynamic_2023 \
    -o "$out/dynamic-2017.vvp" \
    ivtest/ivltests/sv_covergroup_item_goal_comment_extension_dynamic_2023.v \
    >"$out/compile-2017.stdout" 2>"$out/compile-2017.stderr"; then
  :
else
  compile_2017=$?
fi

printf 'compile_2023=%s\nrun_2023=%s\ncompile_2017=%s\n' \
  "$compile_2023" "$run_2023" "$compile_2017" >"$out/result.txt"

if [ "$compile_2023" -ne 0 ] || [ "$run_2023" != 0 ] \
    || [ "$compile_2017" -eq 0 ] \
    || ! grep -q 'embedded covergroup inheritance requires IEEE1800-2023' \
      "$out/compile-2017.stderr" \
    || ! grep -q '^PASSED$' "$out/run-2023.stdout"; then
  exit 1
fi
