#!/bin/sh
set -u

repo=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
attempt="$repo/evidence/ieee1800-audit-c18-c19-20261019/attempt-06-c18.14"
source_file=tests/1800_audit/c18/p18_14_stability.sv
iverilog=/opt/homebrew/bin/iverilog
vvp=/opt/homebrew/bin/vvp
tmpdir=$(mktemp -d /tmp/a3-p18-14.XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

cd "$repo" || exit 1
mkdir -p "$attempt/results"
{
  printf 'Host: '; hostname
  printf 'UTC start: '; date -u '+%Y-%m-%d %H:%M:%S UTC'
  printf 'Git HEAD: '; git rev-parse HEAD
  printf 'Source SHA-256: '; shasum -a 256 "$source_file"
  printf 'iverilog SHA-256: '; shasum -a 256 "$iverilog"
  printf 'vvp SHA-256: '; shasum -a 256 "$vvp"
  "$iverilog" -V | head -2
  "$vvp" -V 2>&1 | head -2
  printf 'Commands: iverilog -g2017/-g2023 -s test; vvp -n\n'
} > "$attempt/results/metadata.txt" 2>&1

rc2017=0
"$iverilog" -g2017 -s test -o "$tmpdir/p18_14_2017.vvp" "$source_file" > "$attempt/results/build-2017.log" 2>&1 || rc2017=$?
if [ "$rc2017" -eq 0 ]; then
  "$vvp" -n "$tmpdir/p18_14_2017.vvp" > "$attempt/results/run-2017.log" 2>&1 || rc2017=$?
fi

rc2023=0
"$iverilog" -g2023 -s test -o "$tmpdir/p18_14_2023.vvp" "$source_file" > "$attempt/results/build-2023.log" 2>&1 || rc2023=$?
if [ "$rc2023" -eq 0 ]; then
  "$vvp" -n "$tmpdir/p18_14_2023.vvp" > "$attempt/results/run-2023.log" 2>&1 || rc2023=$?
fi

printf '2017 exit: %s\n2023 exit: %s\n' "$rc2017" "$rc2023" | tee "$attempt/results/exit-status.txt"
printf 'UTC end: ' >> "$attempt/results/metadata.txt"
date -u '+%Y-%m-%d %H:%M:%S UTC' >> "$attempt/results/metadata.txt"
[ "$rc2017" -eq 0 ] && [ "$rc2023" -eq 0 ]
