#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-1800-c18-null-r2
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01/logs/%x-%j.out
set -Eeuo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01
SRC="$RUN/source"
IVL="$SRC/local-install/bin/iverilog"
VVP="$SRC/local-install/bin/vvp"
OUT="$RUN/audit-results-c18-null-r2"
mkdir -p "$OUT"
exec > >(tee "$OUT/combined.log") 2>&1

echo "host=$(hostname)"
echo "base=82023726be90ab269d6e0ef5e755ebb69e6f648c"
"$IVL" -V > "$OUT/iverilog-version.log" 2>&1
head -n 1 "$OUT/iverilog-version.log"
sha256sum "$IVL" "$VVP"

for edition in 2017 2023; do
  src="$SRC/tests/1800_audit/c18/neg/n18_07_scope_randomize_null.sv"
  if timeout --signal=TERM --kill-after=5s 60s \
    "$IVL" -g"$edition" -s top -o "$OUT/null-$edition.vvp" "$src" \
    > "$OUT/null-$edition.compile.log" 2>&1; then
    echo "std::randomize(null) -g$edition: COMPILED"
    if timeout --signal=TERM --kill-after=5s 60s "$VVP" -n "$OUT/null-$edition.vvp" \
      > "$OUT/null-$edition.run.log" 2>&1; then
      echo "std::randomize(null) -g$edition runtime: EXIT 0"
    else
      echo "std::randomize(null) -g$edition runtime: NONZERO"
    fi
  else
    echo "std::randomize(null) -g$edition: REJECTED"
    cat "$OUT/null-$edition.compile.log"
  fi
done
