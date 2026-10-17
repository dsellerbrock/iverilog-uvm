#!/usr/bin/env bash
#SBATCH --job-name=a3-1800-c19a-bisect
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19a-20261017-02/logs/%x-%j.out
set -Eeuo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c19a-20261017-02
TOOL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
RESULTS="$RUN/results"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/combined.txt") 2>&1

hostname; uname -a; date -Is; nproc
"$TOOL/bin/iverilog" -V >"$RESULTS/iverilog-version.log" 2>&1
sed -n '1,3p' "$RESULTS/iverilog-version.log"

python3 - "$RUN/input/p19_05_bins_cov.sv" "$RESULTS" <<'PY'
from pathlib import Path
import sys
src, out = Path(sys.argv[1]), Path(sys.argv[2])
text = src.read_text()
array_default = "bins others[] = default;"
assert text.count(array_default) == 1
(out / "p19_05_bins_without_default.sv").write_text(
    text.replace(array_default, "// bisect: array default bin removed", 1))
(out / "p19_05_bins_single_default.sv").write_text(
    text.replace(array_default, "bins others = default;", 1))
PY
sha256sum "$RUN/input/p19_05_bins_cov.sv" "$RESULTS"/p19_05_bins_*.sv

for variant in without_default single_default; do
  for edition in 2017 2023; do
    source="$RESULTS/p19_05_bins_${variant}.sv"
    image="$RESULTS/p19_05_bins_${variant}_${edition}.vvp"
    log="$RESULTS/p19_05_bins_${variant}_${edition}.log"
    printf '\n=== %s -g%s ===\n' "$variant" "$edition"
    set +e
    timeout 60 "$TOOL/bin/iverilog" "-g$edition" -s top -o "$image" "$source" >"$log" 2>&1
    rc=$?
    set -e
    echo "compile_rc=$rc"
    cat "$log"
    if [[ $rc -eq 0 ]]; then
      set +e
      timeout 30 "$TOOL/bin/vvp" "$image" >"$RESULTS/p19_05_bins_${variant}_${edition}.run.log" 2>&1
      run_rc=$?
      set -e
      echo "run_rc=$run_rc"
      cat "$RESULTS/p19_05_bins_${variant}_${edition}.run.log"
    fi
  done
done
