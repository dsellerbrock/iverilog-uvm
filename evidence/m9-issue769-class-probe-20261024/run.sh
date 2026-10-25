#!/bin/bash
set +e
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue769-followup-20261024
TMPDIR=/tmp/m9-769-class-probe-20261024
IVL="$REPO/local-install/bin/iverilog"
VVP="$REPO/local-install/bin/vvp"
printf 'host=%s\ncommit=%s\ncompiler=%s\n' "$(hostname)" "$(git -C "$REPO" rev-parse HEAD)" "$($IVL -V 2>&1 | head -1)"
for edition in 2017 2023; do
  for case in select whole; do
    "$IVL" -g"$edition" -o "$TMPDIR/$case-$edition.vvp" "$TMPDIR/class_$case.sv" >"$TMPDIR/$case-$edition.compile.stdout" 2>"$TMPDIR/$case-$edition.compile.stderr"
    rc=$?
    printf '%s compile rc=%s\n' "$case -g$edition" "$rc"
    cat "$TMPDIR/$case-$edition.compile.stderr"
    if [ "$rc" = 0 ]; then
      "$VVP" "$TMPDIR/$case-$edition.vvp" >"$TMPDIR/$case-$edition.runtime.stdout" 2>"$TMPDIR/$case-$edition.runtime.stderr"
      rc=$?
      printf '%s runtime rc=%s\n' "$case -g$edition" "$rc"
      cat "$TMPDIR/$case-$edition.runtime.stdout"
      cat "$TMPDIR/$case-$edition.runtime.stderr"
    fi
  done
done
