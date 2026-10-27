#!/bin/bash
set +e
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue769-followup-20261024
TMPDIR=/tmp/m9-769-class-probe-20261024
IVL="$REPO/local-install/bin/iverilog"
VVP="$REPO/local-install/bin/vvp"
for edition in 2017 2023; do
  "$IVL" -g"$edition" -o "$TMPDIR/assign-$edition.vvp" "$TMPDIR/class_assign.sv" >"$TMPDIR/assign-$edition.compile.stdout" 2>"$TMPDIR/assign-$edition.compile.stderr"
  rc=$?
  printf 'assign/deassign -g%s compile rc=%s\n' "$edition" "$rc"
  cat "$TMPDIR/assign-$edition.compile.stderr"
  if [ "$rc" = 0 ]; then
    "$VVP" "$TMPDIR/assign-$edition.vvp" >"$TMPDIR/assign-$edition.runtime.stdout" 2>"$TMPDIR/assign-$edition.runtime.stderr"
    rc=$?
    printf 'assign/deassign -g%s runtime rc=%s\n' "$edition" "$rc"
    cat "$TMPDIR/assign-$edition.runtime.stdout"
    cat "$TMPDIR/assign-$edition.runtime.stderr"
  fi
done
