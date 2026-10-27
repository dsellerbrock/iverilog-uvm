#!/usr/bin/env bash
set -u

repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$repo_root"
run_dir=evidence/ieee1800-audit-c13e-20261017
log_dir="$run_dir/attempt-02/logs"
iverilog_bin=/tmp/iverilog-uvm-issue457-install/bin/iverilog
vvp_bin=/tmp/iverilog-uvm-issue457-install/bin/vvp
tmpbase=/tmp/a3-c13e-exact-$$

{
  printf 'host=Mac\n'
  date -u
  printf 'compiler_source_commit=21a2ffd199ca6861a420cb7bbf190d0d0215ed85\n'
  printf 'audit_source_commit='
  git rev-parse HEAD
  "$iverilog_bin" -V 2>&1 | head -n 2
  shasum -a 256 "$iverilog_bin" "$vvp_bin"
  shasum -a 256 tests/1800_audit/c13/p13_07_08_names_param.sv tests/1800_audit/c13/neg/n13_08_new_virtual_class.sv
} > "$run_dir/attempt-02/manifest.txt" 2>&1

status=0
: > "$run_dir/results.txt"
for edition in 2017 2023; do
  {
    printf '=== positive -g%s ===\n' "$edition"
    printf 'command: iverilog -g%s -s top tests/1800_audit/c13/p13_07_08_names_param.sv\n' "$edition"
  } >> "$run_dir/results.txt"
  compile_rc=0
  if python3 scripts/run_with_timeout.py 30 -- "$iverilog_bin" -g"$edition" -s top -o "$tmpbase-$edition.vvp" tests/1800_audit/c13/p13_07_08_names_param.sv > "$log_dir/positive-$edition.compile.log" 2>&1; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf 'compile_rc=%s\n' "$compile_rc" >> "$run_dir/results.txt"
  if [ "$compile_rc" -ne 0 ]; then
    cat "$log_dir/positive-$edition.compile.log" >> "$run_dir/results.txt"
    status=1
  else
    run_rc=0
    if python3 scripts/run_with_timeout.py 10 -- "$vvp_bin" "$tmpbase-$edition.vvp" > "$log_dir/positive-$edition.run.log" 2>&1; then
      run_rc=0
    else
      run_rc=$?
    fi
    cat "$log_dir/positive-$edition.run.log" >> "$run_dir/results.txt"
    printf 'run_rc=%s\n' "$run_rc" >> "$run_dir/results.txt"
    if [ "$run_rc" -ne 0 ] || ! rg -q '^DONE fails=0$' "$log_dir/positive-$edition.run.log" || rg -q '^FAIL ' "$log_dir/positive-$edition.run.log"; then
      status=1
    fi
  fi

  {
    printf '=== negative -g%s ===\n' "$edition"
    printf 'command: iverilog -g%s -tnull -s n13_08_new_virtual_class tests/1800_audit/c13/neg/n13_08_new_virtual_class.sv\n' "$edition"
  } >> "$run_dir/results.txt"
  negative_rc=0
  if python3 scripts/run_with_timeout.py 30 -- "$iverilog_bin" -g"$edition" -tnull -s n13_08_new_virtual_class tests/1800_audit/c13/neg/n13_08_new_virtual_class.sv > "$log_dir/negative-$edition.compile.log" 2>&1; then
    negative_rc=0
  else
    negative_rc=$?
  fi
  cat "$log_dir/negative-$edition.compile.log" >> "$run_dir/results.txt"
  printf 'compile_rc=%s (expected nonzero)\n' "$negative_rc" >> "$run_dir/results.txt"
  if [ "$negative_rc" -eq 0 ] || [ "$negative_rc" -eq 124 ] || ! rg -qi 'object of virtual class|virtual class' "$log_dir/negative-$edition.compile.log"; then
    status=1
  else
    printf 'PASS rejected specifically as virtual class instantiation\n' >> "$run_dir/results.txt"
  fi
done

rm -f "$tmpbase-2017.vvp" "$tmpbase-2023.vvp"
printf 'FINAL_STATUS=%s\n' "$status" >> "$run_dir/results.txt"
cat "$run_dir/results.txt"
exit "$status"
