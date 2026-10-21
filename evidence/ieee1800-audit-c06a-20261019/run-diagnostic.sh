#!/usr/bin/env bash
set -u
B=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin
"$B/iverilog" -g2017 -o evidence/ieee1800-audit-c06a-20261019/diagnostic-values.vvp evidence/ieee1800-audit-c06a-20261019/diagnostic-values.sv > evidence/ieee1800-audit-c06a-20261019/diagnostic-values.compile.log 2>&1
rc=$?
echo "compile_rc=$rc"
cat evidence/ieee1800-audit-c06a-20261019/diagnostic-values.compile.log
if [ "$rc" -eq 0 ]; then
  perl -e 'alarm 30; exec @ARGV' "$B/vvp" -n evidence/ieee1800-audit-c06a-20261019/diagnostic-values.vvp > evidence/ieee1800-audit-c06a-20261019/diagnostic-values.run.log 2>&1
  echo "run_rc=$?"
  cat evidence/ieee1800-audit-c06a-20261019/diagnostic-values.run.log
fi
