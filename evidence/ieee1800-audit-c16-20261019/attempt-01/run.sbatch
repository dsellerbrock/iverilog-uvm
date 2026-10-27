#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c16-3
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00

set -euo pipefail

run_dir=${SLURM_SUBMIT_DIR:?}
t2_install=/home/dsell/slurm-runs/iverilog-uvm/A3/t2-batch-20261019-4-r4/source/local-install
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
for edition in 2017 2023; do
    for name in p16_03_simple_assert p16_03_simple_assume p16_03_simple_cover; do
        compile_log="$run_dir/results/$name-$edition.compile.log"
        run_log="$run_dir/results/$name-$edition.run.log"
        binary="$run_dir/results/$name-$edition.vvp"
        echo "=== $name -g$edition ==="
        if ! timeout --signal=TERM --kill-after=5s 120s \
            "$toolchain/bin/iverilog" -B "$toolchain/lib/ivl" -g"$edition" \
            -s test -o "$binary" "$run_dir/input/$name.sv" > "$compile_log" 2>&1; then
            cat "$compile_log"
            failed=1
            continue
        fi
        if ! timeout --signal=TERM --kill-after=5s 120s \
            "$toolchain/bin/vvp" "$binary" > "$run_log" 2>&1; then
            cat "$run_log"
            failed=1
            continue
        fi
        cat "$run_log"
        if ! grep -Fxq PASSED "$run_log"; then
            echo "FAIL: missing PASSED marker from $name -g$edition"
            failed=1
        fi
    done

    name=n16_03_temporal_in_immediate
    compile_log="$run_dir/results/$name-$edition.compile.log"
    echo "=== $name -g$edition (must reject) ==="
    set +e
    timeout --signal=TERM --kill-after=5s 120s \
        "$toolchain/bin/iverilog" -B "$toolchain/lib/ivl" -g"$edition" \
        -s test -o "$run_dir/results/$name-$edition.vvp" \
        "$run_dir/input/neg/$name.sv" > "$compile_log" 2>&1
    compile_rc=$?
    set -e
    cat "$compile_log"
    if [[ $compile_rc -eq 0 || $compile_rc -eq 124 || $compile_rc -eq 137 ]]; then
        echo "FAIL: temporal syntax unexpectedly compiled in -g$edition"
        failed=1
    elif ! grep -Eiq 'syntax error|error:' "$compile_log"; then
        echo "FAIL: compilation failed without a syntax diagnostic in -g$edition"
        failed=1
    else
        echo "PASS: temporal syntax rejected in -g$edition (exit $compile_rc)"
    fi
done

exit "$failed"
