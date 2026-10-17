#!/usr/bin/env bash
#SBATCH --job-name=a3-447-t0t1
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=3
#SBATCH --mem=4G
#SBATCH --time=00:45:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/m5-issue447-boundary-20261015-02/logs/slurm-%j.out
set -euo pipefail

run=/home/dsell/slurm-runs/iverilog-uvm/a3/m5-issue447-boundary-20261015-02
src="$run/source"
logs="$run/logs"
commit=14a0326d21248842044b64a9633cf78a75bf03c2

date --iso-8601=seconds > "$logs/start.txt"
uname -a > "$logs/host.txt"
printf '%s\n' "$commit" > "$logs/commit.txt"
sha256sum "$run/source.tar.gz" > "$logs/source.sha256"
mkdir -p "$src"
tar -xzf "$run/source.tar.gz" -C "$src"
cd "$src"
autoconf > "$logs/autoconf.log" 2>&1
timeout --signal=TERM --kill-after=5s 1200s ./configure --prefix="$src/local-install" > "$logs/configure.log" 2>&1
timeout --signal=TERM --kill-after=5s 1500s /usr/bin/time -v -o "$logs/build.time" make -j3 > "$logs/build.log" 2>&1
timeout --signal=TERM --kill-after=5s 600s make install > "$logs/install.log" 2>&1

export PATH="$src/local-install/bin:$PATH"
export LD_LIBRARY_PATH="$src/local-install/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export IVERILOG="$src/local-install/bin/iverilog"
export VVP="$src/local-install/bin/vvp"
export IVPI="$src/local-install/bin/iverilog-vpi"
export VPI_MODULE_DIR="$src/local-install/lib/ivl"
sha256sum "$IVERILOG" "$VVP" > "$logs/toolchain.sha256"
"$IVERILOG" -V > "$logs/iverilog-version.txt" 2>&1
"$VVP" -V > "$logs/vvp-version.txt" 2>&1

cd "$src/ivtest"
timeout --signal=TERM --kill-after=5s 1200s perl ./vvp_reg.pl "$run/t0-legacy.list" > "$logs/t0-legacy.log" 2>&1
run_json_list() {
    local list_file="$1"
    local log_file="$2"
    : > "$log_file"
    while read -r name json; do
        case "$name" in ''|\#*) continue ;; esac
        printf '%s %s\n' "$name" "$json" > "$run/one-vvp.list"
        timeout --signal=TERM --kill-after=5s 180s python3 ./vvp_reg.py --strict "$run/one-vvp.list" >> "$log_file" 2>&1
    done < "$list_file"
}
run_json_list "$run/t0-vvp.list" "$logs/t0-vvp.log"
printf 'T0_REPRO_RESULT=PASS\n' > "$logs/t0-repro-result.txt"

cd "$src"
timeout --signal=TERM --kill-after=5s 1800s bash ci/run-smoke.sh > "$logs/smoke.log" 2>&1
printf 'SMOKE_RESULT=PASS\n' > "$logs/smoke-result.txt"

cd "$src/ivtest"
timeout --signal=TERM --kill-after=5s 1200s perl ./vvp_reg.pl "$run/t1-control-legacy.list" > "$logs/t1-control-legacy.log" 2>&1
run_json_list "$run/t1-control-vvp.list" "$logs/t1-control-vvp.log"
timeout --signal=TERM --kill-after=5s 1200s perl ./vvp_reg.pl "$run/t1-tree-legacy.list" > "$logs/t1-tree-legacy.log" 2>&1
run_json_list "$run/t1-tree-vvp.list" "$logs/t1-tree-vvp.log"
printf 'T1_RESULT=PASS\n' > "$logs/t1-result.txt"
date --iso-8601=seconds > "$logs/finish.txt"
