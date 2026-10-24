#!/bin/bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-audit-c14-6-7
#SBATCH --cpus-per-task=2
#SBATCH --mem=3G
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x-%j.out
set -euo pipefail

run_dir="$SLURM_SUBMIT_DIR"
mkdir -p "$run_dir/source" "$run_dir/install" "$run_dir/results"
tar -xzf "$run_dir/input/source.tar.gz" -C "$run_dir"
tar -xzf "$run_dir/input/probes.tar.gz" -C "$run_dir/source"
cd "$run_dir/source"

printf 'source_commit=' > "$run_dir/results/metadata.txt"
cat "$run_dir/input/source-commit.txt" >> "$run_dir/results/metadata.txt"
printf 'host=%s\njob_id=%s\ncpus=%s\n' "$(hostname)" "$SLURM_JOB_ID" "$SLURM_CPUS_PER_TASK" >> "$run_dir/results/metadata.txt"
sh autoconf.sh >"$run_dir/results/autoconf.log" 2>&1
./configure --prefix="$run_dir/install" >"$run_dir/results/configure.log" 2>&1
/usr/bin/time -v -o "$run_dir/results/build.time" make -j2 >"$run_dir/results/build.log" 2>&1
make install >"$run_dir/results/install.log" 2>&1
iverilog="$run_dir/install/bin/iverilog"
vvp="$run_dir/install/bin/vvp"
python="$run_dir/source/scripts/run_with_timeout.py"
printf 'iverilog_sha256=' >> "$run_dir/results/metadata.txt"
sha256sum "$iverilog" | awk '{print $1}' >> "$run_dir/results/metadata.txt"
printf 'vvp_sha256=' >> "$run_dir/results/metadata.txt"
sha256sum "$vvp" | awk '{print $1}' >> "$run_dir/results/metadata.txt"
"$iverilog" -V >"$run_dir/results/iverilog-version.txt" 2>&1

status=0
positive() {
    name=$1 edition=$2 stem="$run_dir/results/$1-$2"
    if ! python3 "$python" 120 -- "$iverilog" "-g$edition" -s test -o "$stem.vvp" "tests/1800_audit/c14/$name.sv" >"$stem.compile.log" 2>&1; then
        echo "FAIL compile expected pass: $name -g$edition" | tee -a "$run_dir/results/matrix.txt"
        status=1
        return 0
    fi
    if ! python3 "$python" 120 -- "$vvp" -n "$stem.vvp" >"$stem.run.log" 2>&1 || ! grep -q '^PASSED$' "$stem.run.log"; then
        echo "FAIL run expected pass: $name -g$edition" | tee -a "$run_dir/results/matrix.txt"
        status=1
        return 0
    fi
    echo "PASS: $name -g$edition" | tee -a "$run_dir/results/matrix.txt"
}
reject() {
    name=$1 edition=$2 stem="$run_dir/results/$1-$2"
    if python3 "$python" 120 -- "$iverilog" "-g$edition" -s test -o "$stem.vvp" "tests/1800_audit/c14/neg/$name.sv" >"$stem.compile.log" 2>&1; then
        echo "FAIL compile expected rejection: $name -g$edition" | tee -a "$run_dir/results/matrix.txt"
        status=1
    else
        rc=$?
        if [[ $rc -eq 124 ]] || ! grep -Eiq 'error:|syntax error' "$stem.compile.log"; then
            echo "FAIL unclassified compile result: $name -g$edition (exit $rc)" | tee -a "$run_dir/results/matrix.txt"
            status=1
        else
            echo "REJECTED: $name -g$edition (exit $rc)" | tee -a "$run_dir/results/matrix.txt"
        fi
    fi
}

: > "$run_dir/results/matrix.txt"
for edition in 2017 2023; do
    positive p14_06_shared_signals "$edition"
    positive p14_07_instance_scope "$edition"
    reject n14_07_clocking_in_task "$edition"
    reject n14_07_clocking_in_package "$edition"
    reject n14_07_nested_clocking "$edition"
done
exit "$status"
