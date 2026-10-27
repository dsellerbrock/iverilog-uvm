#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-c07-r9
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=logs/%x-%j.out
set -u
run_dir=${SLURM_SUBMIT_DIR:?}
tool_dir=/home/dsell/toolchains/iverilog-a3-batch-6604c23e-f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd-53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b
mkdir -p "$run_dir/source/tests/1800_audit/c07" "$run_dir/results"
tar -xzf "$run_dir/input/probe.tar.gz" -C "$run_dir/source"
printf 'toolchain=%s\n' "$tool_dir"
sha256sum "$tool_dir/bin/iverilog" "$tool_dir/bin/vvp" > "$run_dir/results/toolchain.sha256"
printf 'edition\tcompile_rc\trun_rc\n' > "$run_dir/results/summary.tsv"
for edition in 2017 2023; do
  compile_rc=0
  run_rc=not_run
  "$tool_dir/bin/iverilog" "-g$edition" -s test \
    -o "$run_dir/results/invalid-index-$edition.vvp" \
    "$run_dir/source/tests/1800_audit/c07/p07_08_invalid_assoc_index.sv" \
    >"$run_dir/results/invalid-index-$edition.compile.log" 2>&1 || compile_rc=$?
  if [[ $compile_rc -eq 0 ]]; then
    run_rc=0
    "$tool_dir/bin/vvp" "$run_dir/results/invalid-index-$edition.vvp" \
      >"$run_dir/results/invalid-index-$edition.stdout.log" \
      2>"$run_dir/results/invalid-index-$edition.stderr.log" || run_rc=$?
  fi
  printf '%s\t%s\t%s\n' "$edition" "$compile_rc" "$run_rc" >> "$run_dir/results/summary.tsv"
done
tar -czf "$run_dir/results-$SLURM_JOB_ID.tar.gz" -C "$run_dir/results" .
sha256sum "$run_dir/results-$SLURM_JOB_ID.tar.gz"
cat "$run_dir/results/summary.tsv"
