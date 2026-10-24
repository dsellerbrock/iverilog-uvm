#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-first-match-26
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-firstmatch-20261019-26
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-firstmatch-20261019-26/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-firstmatch-20261019-26
TOOLCHAIN=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
RESULTS="$RUN_DIR/results"
IVERILOG="$TOOLCHAIN/bin/iverilog"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\ntoolchain_source=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/input"/*.sv | tee "$RESULTS/input.sha256"
sha256sum "$IVERILOG" | tee "$RESULTS/compiler.sha256"
status=0
for edition in 2017 2023; do
  for probe in composed match_item; do
    stem="first-match-${probe}-${edition}"
    set +e
    timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$TOOLCHAIN/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/$stem.vvp" "$RUN_DIR/input/p16_09_08_first_match_${probe}.sv" > "$RESULTS/$stem.compile.log" 2>&1
    compile_rc=$?
    printf 'compile_exit=%s\n' "$compile_rc" >> "$RESULTS/$stem.compile.log"
    set -e
    printf 'probe=%s edition=%s compile_exit=%s\n' "$probe" "$edition" "$compile_rc" | tee -a "$RESULTS/metadata.txt"
    case "$probe" in
      composed) expected='not supported by the automaton engine in this shape yet' ;;
      match_item) expected='syntax error' ;;
    esac
    if test "$compile_rc" -eq 0 || ! rg -q "$expected" "$RESULTS/$stem.compile.log"; then status=1; fi
  done
done
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/metadata.txt"
exit "$status"
