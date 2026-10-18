#!/usr/bin/env bash
#SBATCH --job-name=a3-c18a
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c18a-20261017/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c18a-20261017
SRC="$RUN_DIR/source"
RESULTS="$RUN_DIR/results"
mkdir -p "$SRC" "$RESULTS" "$RUN_DIR/logs"
exec > >(tee -a "$RESULTS/slurm-job.log") 2>&1
status=0
trap 'rc=$?; printf "script_exit=%s\n" "$rc" > "$RESULTS/script.exit"; exit "$rc"' EXIT

tar -xzf "$RUN_DIR/main-9b5fad2.tar.gz" -C "$SRC"
mkdir -p "$SRC/tests/1800_audit/c18/neg" "$SRC/evidence/ieee1800-audit-c18a-20261017"
cp "$RUN_DIR/p18_06_methods.sv" "$SRC/tests/1800_audit/c18/"
cp "$RUN_DIR/n18_06_override_randomize.sv" "$SRC/tests/1800_audit/c18/neg/"
cp "$RUN_DIR/run-probes.sh" "$SRC/evidence/ieee1800-audit-c18a-20261017/"
printf 'BASE_SOURCE=9b5fad2afb4104caa816b257d5bccc40f01b8c66\nPROBE_COMMIT=7909cd987\n'
hostname; uname -a; date -Is; nproc; free -h

run_step() {
    label=$1
    limit=$2
    shift 2
    printf '\n=== %s (timeout %ss) ===\n' "$label" "$limit"
    set +e
    python3 "$SRC/scripts/run_with_timeout.py" "$limit" -- "$@" > "$RESULTS/$label.log" 2>&1
    rc=$?
    set -e
    printf 'step_exit=%s\n' "$rc"
    cat "$RESULTS/$label.log"
    if [[ $rc -ne 0 ]]; then status=1; fi
}

cd "$SRC"
run_step autoconf 120 autoconf
run_step configure 300 ./configure --enable-libveriuser --prefix="$SRC/local-install"
run_step build 1200 make -j3
run_step install 240 make install
export PATH="$SRC/local-install/bin:$PATH"
printf '\n=== tool versions and hashes ===\n'
iverilog -V > "$RESULTS/iverilog-version.log" 2>&1 || status=1
vvp -V > "$RESULTS/vvp-version.log" 2>&1 || status=1
head -4 "$RESULTS/iverilog-version.log"; head -4 "$RESULTS/vvp-version.log"
sha256sum "$SRC/local-install/bin/iverilog" "$SRC/local-install/bin/vvp" | tee "$RESULTS/tool-sha256.txt"
run_step audit-probes 300 bash "$SRC/evidence/ieee1800-audit-c18a-20261017/run-probes.sh" "$RESULTS/probe-output"
cp "$RESULTS/probe-output/results.txt" "$RESULTS/results.txt"
printf '\nAUDIT_JOB_RESULT=%s\n' "$([[ $status -eq 0 ]] && echo PASS || echo FINDINGS_OR_FAILURE)"
rm -rf "$SRC"
exit "$status"
