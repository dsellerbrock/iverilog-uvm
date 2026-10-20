#!/bin/bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-671-t0t1-r5
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
sh autoconf.sh >"$run_dir/results/autoconf.log" 2>&1
./configure --enable-libveriuser --prefix="$run_dir/install" >"$run_dir/results/configure.log" 2>&1
/usr/bin/time -v make -j2 >"$run_dir/results/build.log" 2>&1
make install >"$run_dir/results/install.log" 2>&1
export PATH="$run_dir/install/bin:$PATH"
sha256sum "$run_dir/install/bin/iverilog" "$run_dir/install/bin/vvp"

run_json_list() {
    local list=$1 log=$2 test_line
    : > "$log"
    while IFS= read -r test_line; do
        case "$test_line" in ''|\#*) continue ;; esac
        printf '%s\n' "$test_line" >"$run_dir/input/one-vvp.list"
        printf '=== %s ===\n' "$test_line" >>"$log"
        (cd "$run_dir/source/ivtest" && \
            python3 "$run_dir/source/scripts/run_with_timeout.py" 180 -- \
                python3 ./vvp_reg.py "$run_dir/input/one-vvp.list") >>"$log" 2>&1 || return 1
    done < "$list"
}

# T0: run the issue reproducer in both editions, then A4's smoke set.
grep -E '^sv_dynamic_array_slice_class_property(_2023)?[[:space:]]' \
    ivtest/regress-ch7-queue-focus-legacy.list >"$run_dir/input/issue-legacy.list"
grep -E '^sv_dynamic_array_slice_class_property(_2023)?[[:space:]]' \
    ivtest/regress-ch7-queue-focus-vvp.list >"$run_dir/input/issue-vvp.list"
issue_legacy_status=0
(cd ivtest && perl ./vvp_reg.pl "$run_dir/input/issue-legacy.list") \
    >"$run_dir/results/t0-issue-legacy.log" 2>&1 || issue_legacy_status=$?
for test_name in sv_dynamic_array_slice_class_property sv_dynamic_array_slice_class_property_2023; do
    if [[ -f "$run_dir/source/ivtest/log/$test_name.log" ]]; then
        cp "$run_dir/source/ivtest/log/$test_name.log" \
            "$run_dir/results/$test_name.compiler.log"
    fi
done
if [[ $issue_legacy_status -ne 0 ]]; then
    exit "$issue_legacy_status"
fi
run_json_list "$run_dir/input/issue-vvp.list" "$run_dir/results/t0-issue-json.log"
PATH="$run_dir/install/bin:$PATH" ./ci/run-smoke.sh \
    >"$run_dir/results/t0-smoke.log" 2>&1

# T1: graph-selected dynamic-array/queue slice focus, legacy and JSON runners.
(cd ivtest && perl ./vvp_reg.pl regress-ch7-queue-focus-legacy.list) \
    >"$run_dir/results/t1-ch7-legacy.log" 2>&1
run_json_list "$run_dir/source/ivtest/regress-ch7-queue-focus-vvp.list" \
    "$run_dir/results/t1-ch7-json.log"
