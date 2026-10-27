#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c14-11-r2
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
printf 'iverilog_sha256=%s\nvvp_sha256=%s\n' \
    f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd \
    53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b
"$iverilog" -B "$toolchain/lib/ivl" -V > "$run_dir/results/iverilog-version.txt" 2>&1
head -5 "$run_dir/results/iverilog-version.txt"

infra_fail=0
probe_pos() {
    name=$1 edition=$2
    stem="$run_dir/results/$name-$edition"
    echo "=== $name -g$edition (expected pass) ==="
    if ! timeout --signal=TERM --kill-after=5s 120s \
        "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test \
        -o "$stem.vvp" "$run_dir/input/$name.sv" > "$stem.compile.log" 2>&1; then
        echo "GAP: compile failed for positive probe $name -g$edition"
        cat "$stem.compile.log"
        return 0
    fi
    if timeout --signal=TERM --kill-after=5s 120s "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1 \
       && grep -Fxq PASSED "$stem.run.log"; then
        echo "PASS: $name -g$edition"
        cat "$stem.run.log"
    else
        echo "GAP: positive probe did not pass $name -g$edition"
        cat "$stem.run.log"
    fi
}
probe_neg() {
    name=$1 edition=$2
    stem="$run_dir/results/$name-$edition"
    echo "=== $name -g$edition (expected compile rejection) ==="
    set +e
    timeout --signal=TERM --kill-after=5s 120s \
        "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test \
        -o "$stem.vvp" "$run_dir/input/neg/$name.sv" > "$stem.compile.log" 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
        echo "GAP: invalid cycle-delay placement compiled $name -g$edition"
    elif [[ $rc -eq 124 || $rc -eq 137 ]]; then
        echo "INFRA: timeout compiling $name -g$edition"
        infra_fail=1
    elif grep -Eiq 'error:|syntax error' "$stem.compile.log"; then
        echo "PASS: rejected $name -g$edition (exit $rc)"
        cat "$stem.compile.log"
    else
        echo "GAP: compile failed without a diagnostic $name -g$edition (exit $rc)"
        cat "$stem.compile.log"
    fi
}
probe_expr_zero() {
    edition=$1
    name=p14_11_zero_cycle_delay_expr
    stem="$run_dir/results/$name-$edition"
    echo "=== $name -g$edition ==="
    set +e
    timeout --signal=TERM --kill-after=5s 120s \
        "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -s test \
        -o "$stem.vvp" "$run_dir/input/$name.sv" > "$stem.compile.log" 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then
        echo "INFRA: timeout compiling $name -g$edition"
        infra_fail=1
    elif [[ $edition == 2017 ]]; then
        if [[ $rc -ne 0 ]]; then
            echo "PASS: expression-valued zero rejected in -g2017"
        else
            echo "GAP: expression-valued zero accepted in -g2017"
            timeout --signal=TERM --kill-after=5s 120s "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1 || true
            cat "$stem.run.log"
        fi
    elif [[ $rc -ne 0 ]]; then
        echo "GAP: expression-valued zero failed to compile in -g2023"
        cat "$stem.compile.log"
    elif timeout --signal=TERM --kill-after=5s 120s "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1 \
         && grep -Fxq PASSED "$stem.run.log"; then
        echo "PASS: expression-valued zero suspends in -g2023"
        cat "$stem.run.log"
    else
        echo "GAP: expression-valued zero did not suspend in -g2023"
        cat "$stem.run.log"
    fi
}

for edition in 2017 2023; do
    probe_pos p14_10_clocking_event "$edition"
    probe_pos p14_11_cycle_delay "$edition"
    probe_pos p14_11_zero_cycle_delay_bare "$edition"
    probe_pos p14_11_zero_cycle_delay_after_event "$edition"
    probe_expr_zero "$edition"
    probe_neg n14_11_no_default_clocking "$edition"
    probe_neg n14_11_intra_assignment_delay "$edition"
done
exit "$infra_fail"
