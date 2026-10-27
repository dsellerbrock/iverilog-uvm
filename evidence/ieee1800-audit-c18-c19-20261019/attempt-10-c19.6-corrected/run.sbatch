#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c19-6b
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-6-corrected-20261019/logs/%x-%j.out
set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-6-corrected-20261019
TOOL=/home/dsell/toolchains/iverilog-a3-main-82023726-679
mkdir -p "$RUN/input" "$RUN/results" "$RUN/logs"
cd "$RUN"
sha256sum input/c19-probes.tar.gz > results/input.sha256
tar -xzf input/c19-probes.tar.gz -C input
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
printf 'IVL=%s\nVVP=%s\n' "$IVL" "$VVP" > results/toolchain.txt
sha256sum "$IVL" "$VVP" "$TOOL/lib/ivl/ivl" > results/toolchain.sha256
"$IVL" -B "$TOOL/lib/ivl" -V > results/iverilog-version.log 2>&1
"$VVP" -V > results/vvp-version.log 2>&1
: > results/status.txt
status=0
for edition in 2017 2023; do
  log="$RUN/results/p19_06_cross-$edition.log"
  exe="$RUN/results/p19_06_cross-$edition.vvp"
  if timeout 60 "$IVL" -B "$TOOL/lib/ivl" -g"$edition" -s test "$RUN/input/p19_06_cross.sv" -o "$exe" > "$log" 2>&1; then
    echo "compile-positive-$edition=0" >> results/status.txt
    if timeout 60 "$VVP" "$exe" > "results/p19_06_cross-$edition.run.log" 2>&1 && grep -Fxq 'PASS 19.6 cross coverage' "results/p19_06_cross-$edition.run.log"; then
      echo "run-positive-$edition=0" >> results/status.txt
    else
      echo "run-positive-$edition=1" >> results/status.txt; status=1
    fi
  else
    rc=$?; echo "compile-positive-$edition=$rc" >> results/status.txt; status=1
  fi
  for name in expression_cross cross_other_covergroup; do
    src="$RUN/input/neg/n19_06_${name}.sv"
    log="$RUN/results/n19_06_${name}-$edition.log"
    if timeout 60 "$IVL" -B "$TOOL/lib/ivl" -g"$edition" -s test "$src" -o "$RUN/results/n19_06_${name}-$edition.vvp" > "$log" 2>&1; then
      echo "compile-negative-${name}-$edition=unexpected-success" >> results/status.txt; status=1
    else
      rc=$?
      if [ "$rc" -eq 124 ] || grep -Eqi 'assert:|assertion|segmentation|Aborted|core dumped' "$log"; then
        echo "compile-negative-${name}-$edition=invalid-failure-$rc" >> results/status.txt; status=1
      else
        echo "compile-negative-${name}-$edition=rejected-$rc" >> results/status.txt
      fi
    fi
  done
done
printf 'GATE_RESULT=%s\n' "$([ "$status" -eq 0 ] && echo PASS || echo FAIL)" | tee results/RESULT.txt
exit "$status"
