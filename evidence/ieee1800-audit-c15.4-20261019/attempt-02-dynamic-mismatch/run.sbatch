#!/bin/bash
#SBATCH --job-name=a3-c15-4-mismatch
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=slurm-%j.out

set -u
RUN_DIR=$(pwd)
INPUT_DIR="$RUN_DIR/input"
LOG_DIR="$RUN_DIR/logs"
RESULTS="$RUN_DIR/results.txt"
TOOLCHAIN=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
failed=0
mkdir -p "$LOG_DIR"

printf 'host=%s\nsource=cae035642e056644274a01e98d4422ce286685b4\n' "$(hostname)" > "$RESULTS"
sha256sum "$TOOLCHAIN/iverilog" "$TOOLCHAIN/vvp" "$INPUT_DIR/p15_04_mailbox_dynamic_type.sv" >> "$RESULTS"
for edition in 2017 2023; do
  name="dynamic-mismatch-$edition"
  binary="$RUN_DIR/$name.vvp"
  if timeout -k 5s 60s "$TOOLCHAIN/iverilog" "-g$edition" -gno-icarus-misc -gno-xtypes \
      -s p15_04_mailbox_dynamic_type -o "$binary" \
      "$INPUT_DIR/p15_04_mailbox_dynamic_type.sv" > "$LOG_DIR/$name.compile.log" 2>&1; then
    compile_status=0
  else
    compile_status=$?
  fi
  printf '%s compile_exit=%s\n' "$name" "$compile_status" >> "$RESULTS"
  if [ "$compile_status" -ne 0 ]; then
    failed=1
    continue
  fi
  if timeout -k 5s 60s "$TOOLCHAIN/vvp" -n "$binary" > "$LOG_DIR/$name.run.log" 2>&1; then
    run_status=0
  else
    run_status=$?
  fi
  printf '%s run_exit=%s\n' "$name" "$run_status" >> "$RESULTS"
  if [ "$run_status" -ne 0 ]; then failed=1; fi
done
for log in "$LOG_DIR"/*; do
  printf '\n===== %s =====\n' "${log##*/}" >> "$RESULTS"
  cat "$log" >> "$RESULTS"
done
cat "$RESULTS"
exit "$failed"
