#!/bin/bash
#SBATCH --job-name=a3-c16c-multiclock-multiplicity
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog/a3/c16c-multiclock-multiplicity-20261020-01/logs/%x-%j.out
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog/a3/c16c-multiclock-multiplicity-20261020-01
INPUT="$RUN/input"
OUT="$RUN/results"
TOOL=/home/dsell/toolchains/iverilog-fb584a25-20261020/bin
mkdir -p "$OUT"
printf 'source=fb584a251dd4cc91e56a75be662ccd5ee05c64e9\n' > "$OUT/provenance.txt"
"$TOOL/iverilog" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$INPUT/sv_assert_multiclock_multiplicity.v" > "$OUT/SHA256SUMS"
: > "$OUT/results.tsv"
for edition in 2017 2023; do
  image="$OUT/multiclock-multiplicity-g$edition.vvp"
  set +e
  timeout -k 2 30 "$TOOL/iverilog" -g"$edition" -o "$image" "$INPUT/sv_assert_multiclock_multiplicity.v" > "$OUT/compile-g$edition.log" 2>&1
  crc=$?
  set -e
  printf '%s\tcompile\t%s\n' "$edition" "$crc" >> "$OUT/results.tsv"
  if [ "$crc" -eq 0 ]; then
    set +e
    timeout -k 2 30 "$TOOL/vvp" "$image" > "$OUT/run-g$edition.log" 2>&1
    rrc=$?
    set -e
    printf '%s\trun\t%s\n' "$edition" "$rrc" >> "$OUT/results.tsv"
  fi
done
sha256sum "$OUT"/* > "$OUT/result-sha256.txt"
