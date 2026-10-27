#!/usr/bin/env bash
set -u

RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13e-20261017-attempt03
INPUT="$RUN/input"
LOGS="$RUN/logs"
RESULTS="$RUN/results.txt"
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
IV="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
TIMEOUT=/usr/bin/timeout
status=0
tmpbase="$RUN/build/c13e-$$"

mkdir -p "$LOGS" "$RUN/build"
{
  printf 'host=%s\n' "$(hostname)"
  date -Is
  printf 'slurm_job_id=%s\n' "${SLURM_JOB_ID:-none}"
  printf 'toolchain=%s\n' "$TOOL"
  "$IV" -V 2>&1 | head -n 2
  sha256sum "$IV" "$VVP"
  sha256sum "$INPUT"/*.sv "$INPUT"/neg/*.sv
} > "$RESULTS"

run_positive() {
  local name="$1" edition="$2" file="$3" key="$4"
  local compile_rc=0 run_rc=not-run vvp_file="$tmpbase-$name-$edition.vvp"
  printf '=== %s -g%s ===\n' "$name" "$edition" >> "$RESULTS"
  printf 'command: %s -g%s -s top -o %s %s\n' "$IV" "$edition" "$vvp_file" "$INPUT/$file" >> "$RESULTS"
  if "$TIMEOUT" -k 2s 30s "$IV" -g"$edition" -s top -o "$vvp_file" "$INPUT/$file" > "$LOGS/$name-$edition.compile.log" 2>&1; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf 'compile_rc=%s\n' "$compile_rc" >> "$RESULTS"
  cat "$LOGS/$name-$edition.compile.log" >> "$RESULTS"
  if [ "$compile_rc" -eq 0 ]; then
    if "$TIMEOUT" -k 2s 10s "$VVP" "$vvp_file" > "$LOGS/$name-$edition.run.log" 2>&1; then
      run_rc=0
    else
      run_rc=$?
    fi
    printf 'run_rc=%s\n' "$run_rc" >> "$RESULTS"
    cat "$LOGS/$name-$edition.run.log" >> "$RESULTS"
    case "$key" in
      param)
        if [ "$run_rc" -ne 0 ] || grep -q '^FAIL' "$LOGS/$name-$edition.run.log"; then
          printf 'classification=parameterized static assignment did not pass\n' >> "$RESULTS"
        else
          printf 'classification=parameterized static assignment passed\n' >> "$RESULTS"
        fi
        ;;
      pass)
        if [ "$run_rc" -ne 0 ] || ! grep -q '^PASS' "$LOGS/$name-$edition.run.log" || grep -q '^FAIL' "$LOGS/$name-$edition.run.log"; then status=1; fi
        ;;
      proc)
        if [ "$run_rc" -ne 0 ] || ! grep -q '^DONE fails=0$' "$LOGS/$name-$edition.run.log" || grep -q '^FAIL ' "$LOGS/$name-$edition.run.log"; then status=1; fi
        ;;
    esac
  elif [ "$key" != param ]; then
    status=1
  else
    printf 'classification=compile-rejected; potential parameterized static assignment gap\n' >> "$RESULTS"
  fi
}

run_negative() {
  local edition="$1" rc=0
  printf '=== n13_08_new_virtual_class -g%s ===\n' "$edition" >> "$RESULTS"
  if "$TIMEOUT" -k 2s 30s "$IV" -g"$edition" -tnull -s n13_08_new_virtual_class "$INPUT/neg/n13_08_new_virtual_class.sv" > "$LOGS/negative-$edition.compile.log" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  printf 'compile_rc=%s (expected nonzero)\n' "$rc" >> "$RESULTS"
  cat "$LOGS/negative-$edition.compile.log" >> "$RESULTS"
  if [ "$rc" -eq 0 ] || [ "$rc" -eq 124 ] || ! grep -qi 'object of virtual class' "$LOGS/negative-$edition.compile.log"; then status=1; else printf 'PASS rejected specifically as virtual-class construction\n' >> "$RESULTS"; fi
}

for edition in 2017 2023; do
  run_positive p13_08_assign_param "$edition" p13_08_assign_param.sv param
  run_positive p13_08_assign_plain "$edition" p13_08_assign_plain.sv pass
  run_positive p13_08_assign_module_fn "$edition" p13_08_assign_module_fn.sv pass
  run_positive p13_07_08_proc "$edition" p13_07_08_proc.sv proc
  run_negative "$edition"
done

rm -f "$tmpbase"-*.vvp
printf 'FINAL_STATUS=%s\n' "$status" >> "$RESULTS"
cat "$RESULTS"
exit "$status"
