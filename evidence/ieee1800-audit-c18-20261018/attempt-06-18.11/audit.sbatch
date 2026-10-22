#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-audit-c18-11
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c18-11-20261019-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c18-11-20261019-01/logs/%x-%j.out
set -Eeuo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c18-11-20261019-01
TOOLCHAIN=/home/dsell/toolchains/iverilog-uvm-4bfe7d04
RESULTS="$RUN/results"
TESTS="$RUN/source/tests/1800_audit/c18"
IVL="$TOOLCHAIN/bin/iverilog"
VVP="$TOOLCHAIN/bin/vvp"
export PATH="$TOOLCHAIN/bin:$PATH"
mkdir -p "$RESULTS"
exec > >(tee -a "$RESULTS/combined.log") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

hostname; uname -a; date -Is
"$IVL" -V > "$RESULTS/iverilog-version.log" 2>&1
"$VVP" -V > "$RESULTS/vvp-version.log" 2>&1
sha256sum "$IVL" "$VVP" > "$RESULTS/tool-binaries.sha256"
sha256sum "$TESTS/p18_11_inline_rand_control.sv" \
  "$TESTS/neg/n18_11_randomize_expression.sv" \
  "$TESTS/neg/n18_11_randomize_local.sv" > "$RESULTS/probe-inputs.sha256"

run_timed() {
    label=$1; limit=$2; shift 2
    printf '\n=== %s (timeout %ss) ===\n' "$label" "$limit"
    set +e
    timeout --signal=TERM --kill-after=5s "${limit}s" "$@" > "$RESULTS/$label.log" 2>&1
    rc=$?
    set -e
    cat "$RESULTS/$label.log"
    printf 'step_exit=%s\n' "$rc"
    return "$rc"
}

for edition in 2017 2023; do
    image="$RESULTS/p18_11-$edition.vvp"
    if run_timed "p18_11-$edition.compile" 60 "$IVL" -B "$TOOLCHAIN/lib/ivl" \
      -g"$edition" -s test -o "$image" "$TESTS/p18_11_inline_rand_control.sv"; then
        if run_timed "p18_11-$edition.run" 60 "$VVP" -n "$image"; then
            if ! grep -qx 'PASS in-line random variable control clause 18.11' "$RESULTS/p18_11-$edition.run.log"; then
                status=1
            fi
        else
            status=1
        fi
    else
        status=1
    fi
done

for edition in 2017 2023; do
    for case_name in expression local; do
        label="n18_11_randomize_${case_name}-$edition"
        if run_timed "$label.compile" 60 "$IVL" -B "$TOOLCHAIN/lib/ivl" \
          -g"$edition" -s test "$TESTS/neg/n18_11_randomize_${case_name}.sv"; then
            printf 'unexpected compile success: %s\n' "$label"
            status=1
        elif ! grep -Eiq 'randomize|member|expression|local|syntax|property' "$RESULTS/$label.compile.log"; then
            printf 'compile failed without a relevant diagnostic: %s\n' "$label"
            status=1
        fi
    done
done

printf 'GATE_RESULT=%s\n' "$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
