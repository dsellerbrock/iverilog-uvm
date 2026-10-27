#!/bin/bash
#SBATCH --job-name=a3-c15-4
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --output=slurm-%j.out

set -u
RUN_DIR=$(pwd)
INPUT_DIR="$RUN_DIR/input"
LOG_DIR="$RUN_DIR/logs"
RESULTS="$RUN_DIR/results.txt"
TOOLCHAIN=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
failed=0
mkdir -p "$LOG_DIR"

printf 'host=%s\n' "$(hostname)" > "$RESULTS"
printf 'source=cae035642e056644274a01e98d4422ce286685b4\n' >> "$RESULTS"
"$TOOLCHAIN/iverilog" -V >> "$RESULTS" 2>&1
"$TOOLCHAIN/vvp" -V >> "$RESULTS" 2>&1
sha256sum "$TOOLCHAIN/iverilog" "$TOOLCHAIN/vvp" >> "$RESULTS"
sha256sum "$INPUT_DIR"/*.sv "$INPUT_DIR"/neg/*.sv >> "$RESULTS"

run_positive() {
  local name="$1" edition="$2" top="$3" source="$4" expected="$5"
  local binary="$RUN_DIR/$name.vvp" compile_status run_status
  if timeout -k 5s 90s "$TOOLCHAIN/iverilog" "-g$edition" -gno-icarus-misc -gno-xtypes \
      -s "$top" -o "$binary" "$INPUT_DIR/$source" > "$LOG_DIR/$name.compile.log" 2>&1; then
    compile_status=0
  else
    compile_status=$?
  fi
  printf '%s compile_exit=%s\n' "$name" "$compile_status" >> "$RESULTS"
  if [ "$compile_status" -ne 0 ]; then
    failed=1
    return
  fi
  if timeout -k 5s 90s "$TOOLCHAIN/vvp" -n "$binary" > "$LOG_DIR/$name.run.log" 2>&1; then
    run_status=0
  else
    run_status=$?
  fi
  printf '%s run_exit=%s\n' "$name" "$run_status" >> "$RESULTS"
  if [ "$run_status" -ne 0 ] || ! grep -Fq "$expected" "$LOG_DIR/$name.run.log"; then
    failed=1
  fi
}

run_negative() {
  local name="$1" edition="$2" top="$3" source="$4" status
  if timeout -k 5s 90s "$TOOLCHAIN/iverilog" "-g$edition" -gno-icarus-misc -gno-xtypes \
      -s "$top" -o "$RUN_DIR/$name.vvp" "$INPUT_DIR/$source" > "$LOG_DIR/$name.compile.log" 2>&1; then
    status=0
  else
    status=$?
  fi
  printf '%s expected_compile_failure_exit=%s\n' "$name" "$status" >> "$RESULTS"
  if [ "$status" -eq 0 ]; then
    failed=1
  fi
}

for edition in 2017 2023; do
  run_positive "ops-$edition" "$edition" p15_04_mailbox_ops p15_04_mailbox_ops.sv 'PASS mailbox clause 15.4 core'
  run_positive "dynamic-$edition" "$edition" p15_04_mailbox_dynamic_type p15_04_mailbox_dynamic_type.sv 'PASS mailbox clause 15.4 dynamic type'
  run_negative "typed-mismatch-$edition" "$edition" n15_04_mailbox_typed_mismatch neg/n15_04_mailbox_typed_mismatch.sv
done
run_positive "unbounded-try-put-2023" 2023 p15_04_mailbox_unbounded_try_put_2023 p15_04_mailbox_unbounded_try_put_2023.sv 'PASS 2023 unbounded try_put'

printf 'overall=%s\n' "$([ "$failed" -eq 0 ] && printf PASS || printf FAIL)" >> "$RESULTS"
for log in "$LOG_DIR"/*; do
  printf '\n===== %s =====\n' "${log##*/}" >> "$RESULTS"
  cat "$log" >> "$RESULTS"
done
cat "$RESULTS"
exit "$failed"
