#!/bin/bash
#SBATCH --job-name=a3-c15e-event-formal
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog/a3/c15e-event-formal-20261020-01/logs/%x-%j.out
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog/a3/c15e-event-formal-20261020-01
INPUT="$RUN/input"
OUT="$RUN/results"
TOOL=/home/dsell/toolchains/iverilog-fb584a25-20261020/bin
mkdir -p "$OUT"
printf 'source=fb584a251dd4cc91e56a75be662ccd5ee05c64e9\n' > "$OUT/provenance.txt"
"$TOOL/iverilog" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$INPUT"/*.sv > "$OUT/SHA256SUMS"
: > "$OUT/results.tsv"
for edition in 2017 2023; do
  for name in ev_formal_only ev_task_formal ev_call_fork_only; do
    compile="$OUT/$name-g$edition.compile.log"
    image="$OUT/$name-g$edition.vvp"
    set +e
    timeout -k 2 30 "$TOOL/iverilog" -g"$edition" -o "$image" "$INPUT/$name.sv" > "$compile" 2>&1
    rc=$?
    set -e
    printf '%s\t%s\tcompile\t%s\n' "$edition" "$name" "$rc" >> "$OUT/results.tsv"
    if [ "$rc" -eq 0 ] && [ "$name" != ev_call_fork_only ]; then
      set +e
      timeout -k 2 30 "$TOOL/vvp" "$image" > "$OUT/$name-g$edition.run.log" 2>&1
      run_rc=$?
      set -e
      printf '%s\t%s\trun\t%s\n' "$edition" "$name" "$run_rc" >> "$OUT/results.tsv"
    fi
  done
done
sha256sum "$OUT"/* > "$OUT/result-sha256.txt"
