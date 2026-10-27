#!/usr/bin/env bash
#SBATCH --job-name=a3-c15-4
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:30:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15.4-20261020-02/logs/%x-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15.4-20261020-02
BIN=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
INPUT="$RUN/input"
OUT="$RUN/results"
mkdir -p "$INPUT" "$OUT/logs"
tar -xzf "$RUN/input.tar.gz" -C "$INPUT"
printf 'host=%s\nmain_commit=cae035642e056644274a01e98d4422ce286685b4\n' "$(hostname)" > "$OUT/metadata.txt"
sha256sum "$BIN/iverilog" "$BIN/vvp" >> "$OUT/metadata.txt"
printf 'edition\tprobe\tcompile_rc\trun_rc\texpected\n' > "$OUT/results.tsv"
run_timed() { python3 "$INPUT/run_with_timeout.py" 20 -- "$@"; }

for g in 2017 2023; do
  log="$OUT/logs/p15_04a-g$g.log"
  run_timed "$BIN/iverilog" -g"$g" -o "$OUT/p15_04a-g$g.vvp" "$INPUT/p15_04a_mailbox.sv" >"$log" 2>&1
  crc=$?
  rrc=NA
  if [ "$crc" -eq 0 ]; then
    run_timed "$BIN/vvp" "$OUT/p15_04a-g$g.vvp" >>"$log" 2>&1
    rrc=$?
  fi
  printf '%s\tpositive\t%s\t%s\tRESULT pass=16 fail=0\n' "$g" "$crc" "$rrc" >> "$OUT/results.tsv"

  log="$OUT/logs/r15_get_mismatch-g$g.log"
  run_timed "$BIN/iverilog" -g"$g" -o "$OUT/r15_get_mismatch-g$g.vvp" "$INPUT/r15_get_mismatch.sv" >"$log" 2>&1
  crc=$?
  rrc=NA
  if [ "$crc" -eq 0 ]; then
    run_timed "$BIN/vvp" "$OUT/r15_get_mismatch-g$g.vvp" >>"$log" 2>&1
    rrc=$?
  fi
  printf '%s\truntime_mismatch\t%s\t%s\tno SURVIVED; runtime diagnostic expected\n' "$g" "$crc" "$rrc" >> "$OUT/results.tsv"

  for neg in n15_param_put_int n15_param_get_int; do
    log="$OUT/logs/$neg-g$g.log"
    run_timed "$BIN/iverilog" -g"$g" -o "$OUT/$neg-g$g.vvp" "$INPUT/neg/$neg.sv" >"$log" 2>&1
    crc=$?
    printf '%s\t%s\t%s\tNA\tcompile reject expected\n' "$g" "$neg" "$crc" >> "$OUT/results.tsv"
  done
done
cat "$OUT/results.tsv"
exit 0
