#!/bin/bash
set +e
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue769-followup-20261024
IVL="$REPO/local-install/bin/iverilog"
printf 'host=%s commit=%s compiler=%s\n' "$(hostname)" "$(git -C "$REPO" rev-parse HEAD)" "$("$IVL" -V 2>&1 | head -1)"
for edition in 2017 2023; do
  for test in plain queue1; do
    if [ "$test" = plain ]; then file=/tmp/m9-769-nested-plain-20261024/plain.sv; module=t; else file=/tmp/m9-769-nested-plain-20261024/queue1.sv; module=t; fi
    "$IVL" -g"$edition" -tnull -s "$module" "$file" >"/tmp/m9-769-nested-plain-20261024/$test-$edition.stdout" 2>"/tmp/m9-769-nested-plain-20261024/$test-$edition.stderr"
    rc=$?
    printf '%s -g%s compile rc=%s\n' "$test" "$edition" "$rc"
    cat "/tmp/m9-769-nested-plain-20261024/$test-$edition.stderr"
  done
done
