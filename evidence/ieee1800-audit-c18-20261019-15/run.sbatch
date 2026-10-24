#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c18-15
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c18-15-20261019/logs/slurm-%j.out

set +e
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c18-15-20261019
INPUT="$RUN/input"
RESULTS="$RUN/results"
TOOL=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
IVERILOG="$TOOL/iverilog"
VVP="$TOOL/vvp"
mkdir -p "$RESULTS"
cd "$RUN"

hostname > "$RESULTS/host.txt"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$RESULTS/start-utc.txt"
sha256sum "$IVERILOG" "$VVP" "$INPUT/p18_15_srandom.sv" \
  "$INPUT/n18_15_srandom_no_args.sv" > "$RESULTS/sha256.txt"
"$IVERILOG" -V > "$RESULTS/iverilog-version.txt" 2>&1
"$VVP" -V > "$RESULTS/vvp-version.txt" 2>&1

failed=0
for edition in 2017 2023; do
  positive="$RESULTS/p18_15-$edition"
  /usr/bin/time -v timeout 30 "$IVERILOG" "-g$edition" \
    -o "$positive.vvp" "$INPUT/p18_15_srandom.sv" \
    > "$positive-compile.log" 2>&1
  compile_rc=$?
  printf 'compile_exit=%s\n' "$compile_rc" >> "$positive-compile.log"
  if [ "$compile_rc" -ne 0 ]; then
    failed=1
    continue
  fi
  /usr/bin/time -v timeout 30 "$VVP" "$positive.vvp" \
    > "$positive-run.log" 2>&1
  run_rc=$?
  printf 'run_exit=%s\n' "$run_rc" >> "$positive-run.log"
  if [ "$run_rc" -ne 0 ] || ! grep -Fxq 'PASS srandom clause 18.15' "$positive-run.log"; then
    failed=1
  fi

  negative="$RESULTS/n18_15-$edition"
  /usr/bin/time -v timeout 30 "$IVERILOG" "-g$edition" \
    -o "$negative.vvp" "$INPUT/n18_15_srandom_no_args.sv" \
    > "$negative-compile.log" 2>&1
  negative_rc=$?
  printf 'compile_exit=%s\n' "$negative_rc" >> "$negative-compile.log"
  if [ "$negative_rc" -eq 0 ] \
      || ! grep -Fq 'srandom() method takes 1 arguments, got 0' "$negative-compile.log"; then
    failed=1
  fi
done

date -u '+%Y-%m-%dT%H:%M:%SZ' > "$RESULTS/end-utc.txt"
printf 'audit_probe_exit=%s\n' "$failed" > "$RESULTS/status.txt"
exit "$failed"
