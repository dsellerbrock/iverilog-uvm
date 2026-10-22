#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c16-4
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00

set -euo pipefail

run_dir=${SLURM_SUBMIT_DIR:?}
toolchain=/home/dsell/toolchains/iverilog-a3-batch-6604c23e-f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd-53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
test -x "$iverilog"
test -x "$vvp"

printf 'source_sha=6604c23e197980b69a5b6b69864ff8ef8d05eba3\n'
printf 'iverilog_sha256=f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd\n'
printf 'vvp_sha256=53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b\n'
"$iverilog" -B "$toolchain/lib/ivl" -V > "$run_dir/results/iverilog-version.txt" 2>&1

failed=0
for edition in 2017 2023; do
    for name in p16_04_observed_deferred p16_04_final_deferred p16_04_module_level_deferred; do
        stem="$run_dir/results/$name-$edition"
        echo "=== $name -g$edition ==="
        if ! timeout --signal=TERM --kill-after=5s 120s \
            "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test \
            -o "$stem.vvp" "$run_dir/input/$name.sv" > "$stem.compile.log" 2>&1; then
            cat "$stem.compile.log"
            failed=1
            continue
        fi
        if ! timeout --signal=TERM --kill-after=5s 120s \
            "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1; then
            cat "$stem.run.log"
            failed=1
            continue
        fi
        cat "$stem.run.log"
        if ! grep -Fxq PASSED "$stem.run.log"; then
            echo "FAIL: missing PASSED marker"
            failed=1
        fi
        if [[ $name == p16_04_final_deferred ]]; then
            active=$(grep -nFx ACTIVE_REGION_DONE "$stem.run.log" | cut -d: -f1)
            passed=$(grep -nFx PASSED "$stem.run.log" | cut -d: -f1)
            for marker in FINAL_ASSERT_PASS FINAL_ASSERT_FAIL FINAL_COVER_PASS; do
                action=$(grep -nFx "$marker" "$stem.run.log" | cut -d: -f1)
                if [[ -z $action || -z $active || -z $passed || $action -le $active || $action -ge $passed ]]; then
                    echo "FAIL: $marker did not run after Active and before the next time step"
                    failed=1
                fi
            done
        fi
        if [[ $name == p16_04_module_level_deferred ]] && ! grep -Fxq MODULE_ITEM_FAIL "$stem.run.log"; then
            echo "FAIL: module-level deferred item action did not run"
            failed=1
        fi
    done

    for name in n16_04_nonzero_delay n16_04_block_action; do
        stem="$run_dir/results/$name-$edition"
        echo "=== $name -g$edition (must reject) ==="
        set +e
        timeout --signal=TERM --kill-after=5s 120s \
            "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test \
            -o "$stem.vvp" "$run_dir/input/neg/$name.sv" > "$stem.compile.log" 2>&1
        compile_rc=$?
        set -e
        cat "$stem.compile.log"
        if [[ $compile_rc -eq 0 || $compile_rc -eq 124 || $compile_rc -eq 137 ]] \
           || ! grep -Eiq 'error:|syntax error' "$stem.compile.log"; then
            echo "FAIL: negative probe did not produce a compile-time diagnostic"
            failed=1
        else
            echo "PASS: rejected $name -g$edition (exit $compile_rc)"
        fi
    done
done

exit "$failed"
