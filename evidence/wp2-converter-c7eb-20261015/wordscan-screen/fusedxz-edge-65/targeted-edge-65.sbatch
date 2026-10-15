#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp2-edge65
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:15:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-edge65-c7eb-20261015-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-edge65-c7eb-20261015-r1/logs/%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-edge65-c7eb-20261015-r1
REF_INSTALL=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install
CAND_INSTALL=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-converter-fusedxz-c7eb-20261015-r1/build/candidate/install
SOURCE=$ROOT/input/sv_vpi_wide_index.v
RESULTS=$ROOT/results
mkdir -p "$RESULTS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

printf 'measurement_base=c7ebca768c21c251d9c165c9aff0e363768030b1\n' > "$RESULTS/provenance.txt"
sha256sum "$SOURCE" "$REF_INSTALL/bin/iverilog" "$REF_INSTALL/bin/vvp" \
  "$CAND_INSTALL/bin/iverilog" "$CAND_INSTALL/bin/vvp" > "$RESULTS/provenance-hashes.txt"

for side in reference candidate; do
  if [ "$side" = reference ]; then
    install=$REF_INSTALL
  else
    install=$CAND_INSTALL
  fi
  mkdir -p "$RESULTS/$side"
  (
    cd "$RESULTS/$side"
    "$install/bin/iverilog" -g2012 -o sv_vpi_wide_index.vvp "$SOURCE" > compile.log 2>&1
    "$install/bin/vvp" -n sv_vpi_wide_index.vvp > stdout.log 2> stderr.log
  )
done

cmp "$RESULTS/reference/stdout.log" "$RESULTS/candidate/stdout.log"
cmp "$RESULTS/reference/stderr.log" "$RESULTS/candidate/stderr.log"
grep -Fxq 'PASSED' "$RESULTS/candidate/stdout.log"
sha256sum "$RESULTS/provenance.txt" "$RESULTS/provenance-hashes.txt" \
  "$RESULTS/reference/stdout.log" "$RESULTS/reference/stderr.log" \
  "$RESULTS/candidate/stdout.log" "$RESULTS/candidate/stderr.log" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
