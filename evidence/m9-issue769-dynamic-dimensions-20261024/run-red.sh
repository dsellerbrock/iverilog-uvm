#!/bin/bash
set +e
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue769-followup-20261024
IVL="$REPO/local-install/bin/iverilog"
printf 'commit=%s\ncompiler=%s\n' "$(git -C "$REPO" rev-parse HEAD)" "$("$IVL" -V 2>&1 | head -1)"
for edition in 2017 2023; do
  "$IVL" -g"$edition" -tnull -s sv_force_var_select_nested_legal "$REPO/ivtest/ivltests/sv_force_var_select_nested_legal.v" >"/tmp/m9-769-dynamic-red-20261024/$edition.stdout" 2>"/tmp/m9-769-dynamic-red-20261024/$edition.stderr"
  rc=$?
  printf 'legal nested targets -g%s compile rc=%s\n' "$edition" "$rc"
  cat "/tmp/m9-769-dynamic-red-20261024/$edition.stderr"
done
