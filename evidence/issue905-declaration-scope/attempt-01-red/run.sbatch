#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-905-red
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue905-red-20261021-1748/logs/red-%j.out
set +e
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
cd /home/dsell/slurm-runs/iverilog-uvm/A3/issue905-red-20261021-1748/source || exit 90
for edition in 2017 2023; do
  echo "=== declaration scope positive -g$edition ==="
  timeout 30s "$TOOL/iverilog" -g"$edition" -s sv_default_argument_declaration_scope -o "positive-$edition.vvp" sv_default_argument_declaration_scope.v
  compile_rc=$?
  echo "compile_rc=$compile_rc"
  if [ "$compile_rc" -eq 0 ]; then
    timeout 30s "$TOOL/vvp" "positive-$edition.vvp"
    echo "vvp_rc=$?"
  fi
  echo "=== declaration scope missing enclosing name -g$edition ==="
  timeout 30s "$TOOL/iverilog" -g"$edition" -s sv_default_argument_declaration_scope_missing -o "missing-$edition.vvp" sv_default_argument_declaration_scope_missing.v
  echo "compile_rc=$? (expected nonzero after fix)"
done
echo "baseline repro complete"
