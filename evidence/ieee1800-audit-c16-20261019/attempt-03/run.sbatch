#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c16-4-r2
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

infra_fail=0
for edition in 2017 2023; do
    for name in p16_04_observed_system_action p16_04_final_deferred \
                p16_04_module_level_system_action p16_04_final_user_task_action; do
        stem="$run_dir/results/$name-$edition"
        echo "=== $name -g$edition ==="
        set +e
        timeout --signal=TERM --kill-after=5s 120s \
            "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test \
            -o "$stem.vvp" "$run_dir/input/$name.sv" > "$stem.compile.log" 2>&1
        rc=$?
        set -e
        if [[ $rc -eq 124 || $rc -eq 137 ]]; then
            echo "INFRA: compile timeout $name -g$edition"
            infra_fail=1
            continue
        elif [[ $rc -ne 0 ]]; then
            echo "GAP: expected-positive probe rejected $name -g$edition (exit $rc)"
            cat "$stem.compile.log"
            continue
        fi
        set +e
        timeout --signal=TERM --kill-after=5s 120s \
            "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1
        rc=$?
        set -e
        if [[ $rc -eq 124 || $rc -eq 137 ]]; then
            echo "INFRA: simulation timeout $name -g$edition"
            infra_fail=1
            continue
        elif [[ $rc -ne 0 ]]; then
            echo "GAP: expected-positive probe failed at runtime $name -g$edition (exit $rc)"
            cat "$stem.run.log"
            continue
        fi
        cat "$stem.run.log"
        if ! grep -Fxq PASSED "$stem.run.log"; then
            echo "GAP: missing PASSED marker $name -g$edition"
            continue
        fi
        case "$name" in
            p16_04_observed_system_action)
                [[ $(grep -Fxc STABLE_FAIL "$stem.run.log") -eq 1 ]] \
                    && ! grep -Fxq GLITCH_FAIL "$stem.run.log" \
                    && echo "PASS: stable observed action fires and transient glitch is flushed" \
                    || echo "GAP: observed deferred action/glitch semantics differ"
                ;;
            p16_04_module_level_system_action)
                grep -Fxq MODULE_ITEM_FAIL "$stem.run.log" \
                    && echo "PASS: module-level deferred item executes" \
                    || echo "GAP: module-level deferred item action missing"
                ;;
            p16_04_final_deferred|p16_04_final_user_task_action)
                active=$(grep -nFx ACTIVE_REGION_DONE "$stem.run.log" | cut -d: -f1 || true)
                passed=$(grep -nFx PASSED "$stem.run.log" | cut -d: -f1 || true)
                if [[ $name == p16_04_final_deferred ]]; then
                    markers=(FINAL_ASSERT_PASS FINAL_ASSERT_FAIL FINAL_COVER_PASS)
                else
                    markers=(FINAL_TASK_ACTION)
                fi
                good=1
                for marker in "${markers[@]}"; do
                    action=$(grep -nFx "$marker" "$stem.run.log" | cut -d: -f1 || true)
                    if [[ -z $action || -z $active || -z $passed || $action -le $active || $action -ge $passed ]]; then
                        good=0
                    fi
                done
                if [[ $good -eq 1 ]]; then
                    echo "PASS: final actions run after Active and before the next time step"
                else
                    echo "GAP: final deferred action timing/dispatch differs"
                fi
                ;;
        esac
    done

    for name in n16_04_nonzero_delay n16_04_block_action; do
        stem="$run_dir/results/$name-$edition"
        echo "=== $name -g$edition (must reject) ==="
        set +e
        timeout --signal=TERM --kill-after=5s 120s \
            "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test \
            -o "$stem.vvp" "$run_dir/input/neg/$name.sv" > "$stem.compile.log" 2>&1
        rc=$?
        set -e
        if [[ $rc -eq 124 || $rc -eq 137 ]]; then
            echo "INFRA: negative-probe compile timeout $name -g$edition"
            infra_fail=1
        elif [[ $rc -ne 0 ]] && grep -Eiq 'error:|syntax error' "$stem.compile.log"; then
            echo "PASS: rejected $name -g$edition (exit $rc)"
            cat "$stem.compile.log"
        else
            echo "GAP: rejection behavior differs for $name -g$edition (exit $rc)"
            cat "$stem.compile.log"
        fi
    done
done

exit "$infra_fail"
