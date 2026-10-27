#!/usr/bin/env bash
#SBATCH --job-name=a3-c15-order
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15.4b-20261020-01/logs/%x-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15.4b-20261020-01
BIN=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
INPUT="$RUN/input"
OUT="$RUN/results"
mkdir -p "$INPUT" "$OUT/logs"
printf 'host=%s\nmain_commit=cae035642e056644274a01e98d4422ce286685b4\n' "$(hostname)" > "$OUT/metadata.txt"
sha256sum "$BIN/iverilog" "$BIN/vvp" >> "$OUT/metadata.txt"
printf 'edition\tcompile_rc\trun_rc\n' > "$OUT/results.tsv"
run_timed() { python3 "$INPUT/run_with_timeout.py" 20 -- "$@"; }
for g in 2017 2023; do
  stem="$OUT/p15_04b-g$g"
  run_timed "$BIN/iverilog" -g"$g" -o "$stem.vvp" "$INPUT/r15_04b_waiter_assignment.sv" > "$stem.log" 2>&1
  crc=$?
  rrc=NA
  if [ "$crc" -eq 0 ]; then
    run_timed "$BIN/vvp" "$stem.vvp" >> "$stem.log" 2>&1
    rrc=$?
  fi
  printf '%s\t%s\t%s\n' "$g" "$crc" "$rrc" >> "$OUT/results.tsv"
done
cat "$OUT/results.tsv"
exit 0
