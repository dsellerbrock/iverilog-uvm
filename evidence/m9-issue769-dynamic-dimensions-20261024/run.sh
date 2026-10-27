#!/bin/bash
set +e
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue769-followup-20261024
TMPDIR=/tmp/m9-769-nested-dynamic-20261024
IVL="$REPO/local-install/bin/iverilog"
printf 'commit=%s\ncompiler=%s\n' "$(git -C "$REPO" rev-parse HEAD)" "$("$IVL" -V 2>&1 | head -1)"
for edition in 2017 2023; do
  for case in whole_nested bit_nested; do
    "$IVL" -g"$edition" -tnull "$TMPDIR/$case.sv" >"$TMPDIR/$case-$edition.stdout" 2>"$TMPDIR/$case-$edition.stderr"
    rc=$?
    printf '%s -g%s compile rc=%s\n' "$case" "$edition" "$rc"
    cat "$TMPDIR/$case-$edition.stderr"
  done
done
