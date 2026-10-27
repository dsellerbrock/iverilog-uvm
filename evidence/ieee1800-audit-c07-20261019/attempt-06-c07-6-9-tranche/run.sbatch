#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-c07-r6
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00
#SBATCH --output=logs/%x-%j.out
set -u

run_dir=${SLURM_SUBMIT_DIR:?}
tool_dir=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
mkdir -p "$run_dir/source" "$run_dir/results"
tar -xzf "$run_dir/input/probes.tar.gz" -C "$run_dir/source"
printf 'toolchain=%s\n' "$tool_dir"
sha256sum "$tool_dir/bin/iverilog" "$tool_dir/bin/vvp" \
  > "$run_dir/results/toolchain.sha256"
printf 'case\tedition\tcompile_rc\trun_rc\n' > "$run_dir/results/summary.tsv"

run_case() {
  test_name=$1
  edition=$2
  test_path="$run_dir/source/tests/1800_audit/c07/$test_name.sv"
  executable="$run_dir/results/$test_name-$edition.vvp"
  compile_log="$run_dir/results/$test_name-$edition.compile.log"
  stdout_log="$run_dir/results/$test_name-$edition.stdout.log"
  stderr_log="$run_dir/results/$test_name-$edition.stderr.log"
  compile_rc=0
  run_rc=not_run

  python3 "$run_dir/source/scripts/run_with_timeout.py" 120 -- \
    "$tool_dir/bin/iverilog" "-g$edition" -s test -o "$executable" "$test_path" \
    >"$compile_log" 2>&1 || compile_rc=$?
  if [[ $compile_rc -eq 0 ]]; then
    run_rc=0
    python3 "$run_dir/source/scripts/run_with_timeout.py" 120 -- \
      "$tool_dir/bin/vvp" "$executable" >"$stdout_log" 2>"$stderr_log" || run_rc=$?
  fi
  printf '%s\t%s\t%s\t%s\n' "$test_name" "$edition" "$compile_rc" "$run_rc" \
    >> "$run_dir/results/summary.tsv"
}

for edition in 2017 2023; do
  run_case p07_04_memory "$edition"
  run_case p07_06_array_assignments "$edition"
  run_case p07_08_assoc_methods_literals "$edition"
  run_case p07_08_invalid_assoc_index "$edition"
  run_case p07_03_02_inactive_tag_read "$edition"
done

tar -czf "$run_dir/results-$SLURM_JOB_ID.tar.gz" -C "$run_dir/results" .
sha256sum "$run_dir/results-$SLURM_JOB_ID.tar.gz"
cat "$run_dir/results/summary.tsv"
