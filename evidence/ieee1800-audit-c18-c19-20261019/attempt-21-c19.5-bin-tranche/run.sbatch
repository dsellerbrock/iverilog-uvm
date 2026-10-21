#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c19-5bins
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00

set -euo pipefail

run_dir=${SLURM_SUBMIT_DIR:?}
t2_install=/home/dsell/slurm-runs/iverilog-uvm/A3/t2-batch-20261019-4-r4/source/local-install
mkdir -p "$run_dir/results"
ivl_sha=$(sha256sum "$t2_install/bin/iverilog" | cut -d' ' -f1)
vvp_sha=$(sha256sum "$t2_install/bin/vvp" | cut -d' ' -f1)
toolchain="/home/dsell/toolchains/iverilog-a3-batch-6604c23e-$ivl_sha-$vvp_sha"
test -x "$toolchain/bin/iverilog"
test -x "$toolchain/bin/vvp"

printf 'source_sha=6604c23e197980b69a5b6b69864ff8ef8d05eba3\n'
printf 'iverilog_sha256=%s\nvvp_sha256=%s\n' "$ivl_sha" "$vvp_sha"
"$toolchain/bin/iverilog" -B "$toolchain/lib/ivl" -V > "$run_dir/results/iverilog-version.txt" 2>&1
head -5 "$run_dir/results/iverilog-version.txt"

failed=0
for name in \
    p19_05_02_transition_bins \
    p19_05_03_auto_bins \
    p19_05_04_wildcard_bins \
    p19_05_05_ignore_bins \
    n19_05_06_illegal_bins_runtime; do
    for edition in 2017 2023; do
        compile_log="$run_dir/results/$name-$edition.compile.log"
        run_log="$run_dir/results/$name-$edition.run.log"
        binary="$run_dir/results/$name-$edition.vvp"
        echo "=== $name -g$edition ==="
        set +e
        timeout --signal=TERM --kill-after=5s 120s \
            "$toolchain/bin/iverilog" -B "$toolchain/lib/ivl" -g"$edition" \
            -s test -o "$binary" "$run_dir/input/$name.sv" > "$compile_log" 2>&1
        compile_rc=$?
        set -e
        printf '%s\t-g%s\tcompile_exit=%s\n' "$name" "$edition" "$compile_rc" >> "$run_dir/results/summary.tsv"
        if [[ $compile_rc -ne 0 ]]; then
            cat "$compile_log"
            failed=1
            continue
        fi

        set +e
        timeout --signal=TERM --kill-after=5s 120s \
            "$toolchain/bin/vvp" "$binary" > "$run_log" 2>&1
        run_rc=$?
        set -e
        printf '%s\t-g%s\trun_exit=%s\n' "$name" "$edition" "$run_rc" >> "$run_dir/results/summary.tsv"
        cat "$run_log"

        if [[ $name == n19_05_06_illegal_bins_runtime ]]; then
            if ! grep -Eiq 'ERROR:|illegal' "$run_log"; then
                echo "FAIL: no illegal-bin runtime diagnostic from $name -g$edition"
                failed=1
            else
                echo "PASS: illegal-bin runtime diagnostic observed"
            fi
        else
            expected_marker="${name^^}_PASS"
            if [[ $run_rc -ne 0 ]] || ! grep -Fxq "$expected_marker" "$run_log"; then
                echo "FAIL: positive probe failed for $name -g$edition"
                failed=1
            else
                echo "PASS: $name -g$edition"
            fi
        fi
    done
done

exit "$failed"
