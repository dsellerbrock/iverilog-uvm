#!/bin/bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-671-t0t1
#SBATCH --cpus-per-task=2
#SBATCH --mem=3G
#SBATCH --time=00:45:00
#SBATCH --output=logs/%x-%j.out
set -euo pipefail

run_dir="$SLURM_SUBMIT_DIR"
mkdir -p "$run_dir/source" "$run_dir/results"
tar -xzf "$run_dir/input/source.tar.gz" -C "$run_dir/source"
cd "$run_dir/source"
printf 'source_commit='
cat "$run_dir/input/commit.txt"
./configure --prefix="$run_dir/install" >"$run_dir/results/configure.log" 2>&1
/usr/bin/time -v make -j2 >"$run_dir/results/build.log" 2>&1
/usr/bin/time -v make check >"$run_dir/results/make-check.log" 2>&1
make install >"$run_dir/results/install.log" 2>&1
export PATH="$run_dir/install/bin:$PATH"
sha256sum "$run_dir/install/bin/iverilog" "$run_dir/install/bin/vvp"

# T0: run the issue reproducer in both editions, then A4's smoke set.
grep -E '^sv_dynamic_array_slice_class_property(_2023)?[[:space:]]' \
    ivtest/regress-ch7-queue-focus-legacy.list >"$run_dir/input/issue-legacy.list"
grep -E '^sv_dynamic_array_slice_class_property(_2023)?[[:space:]]' \
    ivtest/regress-ch7-queue-focus-vvp.list >"$run_dir/input/issue-vvp.list"
(cd ivtest && perl ./vvp_reg.pl "$run_dir/input/issue-legacy.list") \
    >"$run_dir/results/t0-issue-legacy.log" 2>&1
(cd ivtest && python3 ./vvp_reg.py "$run_dir/input/issue-vvp.list") \
    >"$run_dir/results/t0-issue-json.log" 2>&1
PATH="$run_dir/install/bin:$PATH" ./ci/run-smoke.sh \
    >"$run_dir/results/t0-smoke.log" 2>&1

# T1: graph-selected dynamic-array/queue slice focus, legacy and JSON runners.
(cd ivtest && perl ./vvp_reg.pl regress-ch7-queue-focus-legacy.list) \
    >"$run_dir/results/t1-ch7-legacy.log" 2>&1
(cd ivtest && python3 ./vvp_reg.py regress-ch7-queue-focus-vvp.list) \
    >"$run_dir/results/t1-ch7-json.log" 2>&1
