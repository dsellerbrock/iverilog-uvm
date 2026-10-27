#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c16-9-2
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
set -euo pipefail
run_dir=${SLURM_SUBMIT_DIR:?}
toolchain=/home/dsell/toolchains/iverilog-a3-batch-6604c23e-f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd-53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
printf 'source_sha=6604c23e197980b69a5b6b69864ff8ef8d05eba3\n'
printf 'iverilog_sha256=f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd\n'
printf 'vvp_sha256=53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b\n'
"$iverilog" -B "$toolchain/lib/ivl" -V > "$run_dir/results/iverilog-version.txt" 2>&1
infra_fail=0
for edition in 2017 2023; do
  for name in p16_09_02_consecutive_rep p16_09_02_goto_rep p16_09_02_nonconsecutive_rep; do
    stem="$run_dir/results/$name-$edition"
    echo "=== $name -g$edition ==="
    set +e
    timeout --signal=TERM --kill-after=5s 120s "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test -o "$stem.vvp" "$run_dir/input/$name.sv" > "$stem.compile.log" 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then
      echo "INFRA: compile timeout $name -g$edition"; infra_fail=1; continue
    elif [[ $rc -ne 0 ]]; then
      echo "GAP: compile failed $name -g$edition (exit $rc)"; cat "$stem.compile.log"; continue
    fi
    set +e
    timeout --signal=TERM --kill-after=5s 120s "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then
      echo "INFRA: simulation timeout $name -g$edition"; infra_fail=1
    elif [[ $rc -ne 0 ]] || ! grep -q '^PASSED:' "$stem.run.log"; then
      echo "GAP: runtime failed $name -g$edition (exit $rc)"; cat "$stem.run.log"
    else
      echo "PASS: $name -g$edition"; cat "$stem.run.log"
    fi
  done
done
exit "$infra_fail"
