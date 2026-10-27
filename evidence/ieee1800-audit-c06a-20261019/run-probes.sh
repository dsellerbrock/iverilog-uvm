#!/usr/bin/env bash
set -uo pipefail
B=${IVERILOG_BIN:-/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install/bin}
E=${RESULT_DIR:-logs}
mkdir -p "$E"
echo "HOST: $(uname -a)"
echo "TOOLCHAIN: /home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66"
echo "SOURCE COMMIT: 9b5fad2afb4104caa816b257d5bccc40f01b8c66"
"$B/iverilog" -V 2>&1 | head -2
sha256sum "$B/iverilog" "$B/vvp"
for g in 2017 2023; do
  for f in tests/1800_audit/c06/p06_16*.sv; do
    b=$(basename "$f" .sv)
    rm -f "$E/$b.$g.vvp"
    echo "### $b -g$g"
    perl -e 'alarm 60; exec @ARGV' "$B/iverilog" -g"$g" -o "$E/$b.$g.vvp" "$f" >"$E/$b.$g.compile.log" 2>&1
    rc=$?
    echo "compile_rc=$rc"
    cat "$E/$b.$g.compile.log"
    if [ -f "$E/$b.$g.vvp" ]; then
      perl -e 'alarm 60; exec @ARGV' "$B/vvp" -n "$E/$b.$g.vvp" >"$E/$b.$g.run.log" 2>&1
      rc=$?
      echo "run_rc=$rc"
      cat "$E/$b.$g.run.log"
    else
      echo "run_rc=not-run; no .vvp generated"
    fi
  done
  for f in tests/1800_audit/c06/neg/n06_16_*.sv; do
    b=$(basename "$f" .sv)
    rm -f "$E/$b.$g.vvp"
    echo "### $b -g$g"
    perl -e 'alarm 60; exec @ARGV' "$B/iverilog" -g"$g" -o "$E/$b.$g.vvp" "$f" >"$E/$b.$g.compile.log" 2>&1
    rc=$?
    echo "compile_rc=$rc vvp_generated=$([ -f "$E/$b.$g.vvp" ] && echo yes || echo no)"
    cat "$E/$b.$g.compile.log"
  done
done
