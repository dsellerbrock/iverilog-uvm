#!/bin/bash
#SBATCH --job-name=a3-c14-clock-scope
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog/a3/c14b-clock-scope-20261020-01/logs/%x-%j.out
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog/a3/c14b-clock-scope-20261020-01
INPUT="$RUN/input"
OUT="$RUN/results"
TOOL=/home/dsell/toolchains/iverilog-fb584a25-20261020/bin
mkdir -p "$OUT"
printf 'source=fb584a251dd4cc91e56a75be662ccd5ee05c64e9\n' > "$OUT/provenance.txt"
"$TOOL/iverilog" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$INPUT"/*.sv "$INPUT"/*.v > "$OUT/SHA256SUMS"
: > "$OUT/results.tsv"
run_case() {
  local edition="$1" name="$2" file="$3" expected="$4"
  local compile="$OUT/$name-g$edition.compile.log" image="$OUT/$name-g$edition.vvp"
  set +e
  timeout -k 2 30 "$TOOL/iverilog" -g"$edition" -o "$image" "$INPUT/$file" > "$compile" 2>&1
  local rc=$?
  set -e
  printf '%s\t%s\tcompile\t%s\t%s\n' "$edition" "$name" "$expected" "$rc" >> "$OUT/results.tsv"
  if [ "$rc" -eq 0 ] && [ "$expected" = pass ]; then
    set +e
    timeout -k 2 30 "$TOOL/vvp" "$image" > "$OUT/$name-g$edition.run.log" 2>&1
    local rrc=$?
    set -e
    printf '%s\t%s\trun\t0\t%s\n' "$edition" "$name" "$rrc" >> "$OUT/results.tsv"
  fi
}
for edition in 2017 2023; do
  run_case "$edition" program_clocking sv_program_clocking_finish.v pass
  run_case "$edition" checker_default_clocking sv_checker_basic.v pass
  run_case "$edition" checker_named_clocking p14_07_clocking_checker.sv pass
  run_case "$edition" compilation_unit_clocking n14_07_clocking_compilation_unit.sv fail
 done
sha256sum "$OUT"/* > "$OUT/result-sha256.txt"
