#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-13
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c18-13-20261019-01/logs/%x-%j.out
set -Eeuo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c18-13-20261019-01
SRC="$RUN/input"
RESULTS="$RUN/results"
IVL=/home/dsell/toolchains/iverilog-a3-issue680-234d4e6/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-a3-issue680-234d4e6/bin/vvp
mkdir -p "$RESULTS"
exec > >(tee "$RESULTS/runner.log") 2>&1
set +e
status=0
trap 'rc=$?; printf "%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

cd "$SRC"
hostname
date -Is
printf 'audit_head=%s\n' '27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e'
sha256sum "$IVL" "$VVP" | tee "$RESULTS/compiler.sha256"
"$IVL" -V > "$RESULTS/iverilog-version.log" 2>&1
"$VVP" -V > "$RESULTS/vvp-version.log" 2>&1

for edition in 2017 2023; do
    printf '\n=== positive -g%s ===\n' "$edition"
    timeout -k 5s 120s "$IVL" -g"$edition" -s test \
        -o "$RESULTS/positive-$edition.vvp" \
        tests/1800_audit/c18/p18_13_urandom.sv \
        > "$RESULTS/positive-compile-$edition.log" 2>&1
    rc=$?
    printf 'compile_exit=%s\n' "$rc"
    if [[ $rc -ne 0 ]]; then status=1; continue; fi
    timeout -k 5s 120s "$VVP" -n "$RESULTS/positive-$edition.vvp" \
        > "$RESULTS/positive-run-$edition.log" 2>&1
    rc=$?
    cat "$RESULTS/positive-run-$edition.log"
    printf 'run_exit=%s\n' "$rc"
    if [[ $rc -ne 0 ]] || ! grep -qx 'PASS urandom clause 18.13' "$RESULTS/positive-run-$edition.log"; then
        status=1
    fi

    printf '\n=== negative -g%s ===\n' "$edition"
    timeout -k 5s 120s "$IVL" -g"$edition" -s test \
        -o "$RESULTS/negative-$edition.vvp" \
        tests/1800_audit/c18/neg/n18_13_urandom_args.sv \
        > "$RESULTS/negative-compile-$edition.log" 2>&1
    rc=$?
    printf 'compile_exit=%s\n' "$rc"
    cat "$RESULTS/negative-compile-$edition.log"
    if [[ $rc -eq 0 || $rc -eq 124 || $rc -eq 137 ]]; then status=1; fi
done

printf 'GATE_RESULT=%s\n' "$([[ $status -eq 0 ]] && echo PASS || echo FAIL)"
exit "$status"
