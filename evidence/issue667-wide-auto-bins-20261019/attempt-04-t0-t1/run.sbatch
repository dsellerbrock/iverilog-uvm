#!/usr/bin/env bash
#SBATCH --job-name=a3-667-t0t1-r3
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=3G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue667-wide-auto-bins-20261019-t0t1-r3/logs/%x-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/issue667-wide-auto-bins-20261019-t0t1-r3
SOURCE="$RUN_DIR/source"
INSTALL="$RUN_DIR/install"
RESULTS="$RUN_DIR/results"
mkdir -p "$SOURCE" "$RESULTS"
date -Is | tee "$RESULTS/start-time.txt"
hostname | tee "$RESULTS/host.txt"
tar -xzf "$RUN_DIR/input/source.tar.gz" -C "$SOURCE"
cd "$SOURCE"
timeout --signal=TERM --kill-after=30 120 autoconf >"$RESULTS/autoconf.log" 2>&1
timeout --signal=TERM --kill-after=30 1800 ./configure --prefix="$INSTALL" >"$RESULTS/configure.log" 2>&1
timeout --signal=TERM --kill-after=30 3600 /usr/bin/time -v make -j3 >"$RESULTS/build.log" 2>&1
timeout --signal=TERM --kill-after=30 600 make install >"$RESULTS/install.log" 2>&1
export PATH="$INSTALL/bin:$PATH"
sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" >"$RESULTS/installed-tool-hashes.txt"
cd "$SOURCE/ivtest"
grep -E '^sv_covergroup_wide_auto_bins(_2023)?[[:space:]]' regress-sv.list >"$RESULTS/t0-issue-legacy.list"
grep -E '^sv_covergroup_wide_auto_bins(_2023)?[[:space:]]' regress-vvp.list >"$RESULTS/t0-issue-json.list"
timeout --signal=TERM --kill-after=10 300 perl ./vvp_reg.pl "$RESULTS/t0-issue-legacy.list" >"$RESULTS/t0-issue-legacy.log" 2>&1
timeout --signal=TERM --kill-after=10 300 python3 ./vvp_reg.py "$RESULTS/t0-issue-json.list" >"$RESULTS/t0-issue-json.log" 2>&1
cd "$SOURCE"
timeout --signal=TERM --kill-after=30 1800 ./ci/run-smoke.sh >"$RESULTS/t0-smoke.log" 2>&1
cd "$SOURCE/ivtest"
awk '$1 ~ /^sv_covergroup_/ { print }' regress-sv.list >"$RESULTS/t1-covergroup-legacy.list"
awk '$1 ~ /^sv_covergroup_/ { print }' regress-vvp.list >"$RESULTS/t1-covergroup-json.list"
wc -l "$RESULTS/t1-covergroup-legacy.list" "$RESULTS/t1-covergroup-json.list" >"$RESULTS/t1-test-counts.txt"
timeout --signal=TERM --kill-after=10 2400 perl ./vvp_reg.pl "$RESULTS/t1-covergroup-legacy.list" >"$RESULTS/t1-covergroup-legacy.log" 2>&1
timeout --signal=TERM --kill-after=10 2400 python3 ./vvp_reg.py "$RESULTS/t1-covergroup-json.list" >"$RESULTS/t1-covergroup-json.log" 2>&1
date -Is | tee "$RESULTS/end-time.txt"
echo 'T0/T1 PASS' | tee "$RESULTS/result.txt"
