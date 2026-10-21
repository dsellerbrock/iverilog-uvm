#!/bin/bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-671-red
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x-%j.out
set -euo pipefail

run_dir="$SLURM_SUBMIT_DIR"
toolchain=/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin
mkdir -p "$run_dir/work" "$run_dir/results"
sha256sum "$toolchain/iverilog" "$toolchain/vvp"
cp "$run_dir/input/sv_dynamic_array_slice_class_property.v" "$run_dir/work/"

for standard in 2017 2023; do
    set +e
    python3 "$run_dir/input/run_with_timeout.py" 120 -- \
        "$toolchain/iverilog" "-g$standard" -s test \
        -o "$run_dir/work/test-$standard.vvp" \
        "$run_dir/work/sv_dynamic_array_slice_class_property.v" \
        >"$run_dir/results/compile-$standard.log" 2>&1
    status=$?
    set -e
    printf 'compile -g%s exit=%s\n' "$standard" "$status"
    cat "$run_dir/results/compile-$standard.log"
done
