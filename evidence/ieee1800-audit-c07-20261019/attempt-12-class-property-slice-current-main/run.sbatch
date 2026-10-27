#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-c07-r12
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=logs/%x-%j.out
set -u
run_dir=${SLURM_SUBMIT_DIR:?}
tool_dir=/home/dsell/toolchains/iverilog-a3-batch-6604c23e-f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd-53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b
mkdir -p "$run_dir/source" "$run_dir/results"
tar -xzf "$run_dir/input/probe.tar.gz" -C "$run_dir/source"
sha256sum "$tool_dir/bin/iverilog" "$tool_dir/bin/vvp" > "$run_dir/results/toolchain.sha256"
printf 'edition\tcompile_rc\n' > "$run_dir/results/summary.tsv"
for edition in 2017 2023; do
  rc=0
  timeout 120 "$tool_dir/bin/iverilog" "-g$edition" -s test \
    -o "$run_dir/results/class-slice-$edition.vvp" \
    "$run_dir/source/tests/1800_audit/c07/p07_06_class_property_slice.sv" \
    >"$run_dir/results/class-slice-$edition.compile.log" 2>&1 || rc=$?
  printf '%s\t%s\n' "$edition" "$rc" >> "$run_dir/results/summary.tsv"
done
tar -czf "$run_dir/results-$SLURM_JOB_ID.tar.gz" -C "$run_dir/results" .
sha256sum "$run_dir/results-$SLURM_JOB_ID.tar.gz"
cat "$run_dir/results/summary.tsv"
