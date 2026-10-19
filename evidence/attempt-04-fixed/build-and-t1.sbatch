#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-680-t0t1-r2
#SBATCH --cpus-per-task=3
#SBATCH --mem=6G
#SBATCH --time=00:40:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01/logs/%x-%j.out
set -Eeuo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01
SRC="$RUN/source"
BUILD="$SRC"
INSTALL="$SRC/local-install"
mkdir -p "$RUN/results" "$SRC"
exec > >(tee -a "$RUN/results/combined.log") 2>&1

echo "host=$(hostname)"
echo "head=82023726be90ab269d6e0ef5e755ebb69e6f648c"
echo "build_threads=${SLURM_CPUS_PER_TASK:-3} mem_limit=6G"
sha256sum "$RUN/base.tar.gz" "$RUN/feature.patch" \
  "$RUN/issue-repro.sv" > "$RUN/results/input-sha256.txt"
tar -xzf "$RUN/base.tar.gz" -C "$SRC"
patch -p1 -d "$SRC" < "$RUN/feature.patch"

cd "$SRC"
sh ./autoconf.sh > "$RUN/results/autoconf.log" 2>&1
timeout --signal=TERM --kill-after=10s 1200s \
  "$SRC/configure" --prefix="$INSTALL" --enable-libveriuser \
  > "$RUN/results/configure.log" 2>&1
timeout --signal=TERM --kill-after=10s 1200s \
  make -j"${SLURM_CPUS_PER_TASK:-3}" > "$RUN/results/build.log" 2>&1
timeout --signal=TERM --kill-after=10s 600s \
  make install > "$RUN/results/install.log" 2>&1

export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog"
export IVPI="$INSTALL/bin/iverilog-vpi"
export VVP="$INSTALL/bin/vvp"
"$INSTALL/bin/iverilog" -V > "$RUN/results/iverilog-version.log" 2>&1
"$INSTALL/bin/vvp" -V > "$RUN/results/vvp-version.log" 2>&1
sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" \
  > "$RUN/results/tool-binaries.sha256"

status_t0=0
for edition in 2017 2023; do
  compiled=0
  if timeout --signal=TERM --kill-after=5s 60s \
    "$INSTALL/bin/iverilog" -B "$INSTALL/lib/ivl" \
    -g"$edition" -gassertions -s top \
    -o "$RUN/results/issue-$edition.vvp" "$RUN/issue-repro.sv" \
    > "$RUN/results/issue-$edition.compile.log" 2>&1; then
    compiled=1
  else
    status_t0=1
  fi
  if [[ $compiled -eq 1 ]]; then
    timeout --signal=TERM --kill-after=5s 60s \
      "$INSTALL/bin/vvp" -n "$RUN/results/issue-$edition.vvp" \
      > "$RUN/results/issue-$edition.run.log" 2>&1 || status_t0=1
    grep -qx 'PASS issue 680 package function in inline constraint' \
      "$RUN/results/issue-$edition.run.log" || status_t0=1
  fi
done
if [[ $status_t0 -eq 0 ]]; then echo 'T0 issue reproducer: PASS'; else echo 'T0 issue reproducer: FAIL'; fi

cd "$SRC"
timeout --signal=TERM --kill-after=10s 1800s \
  bash ./ci/run-smoke.sh > "$RUN/results/smoke.log" 2>&1 || status_t0=1
if [[ $status_t0 -eq 0 ]]; then echo 'T0 status: PASS'; else echo 'T0 status: FAIL'; fi

status_t1=0
cd "$SRC/ivtest"
timeout --signal=TERM --kill-after=10s 1800s \
  perl ./vvp_reg.pl ./regress-constraint-functions-legacy.list \
  > "$RUN/results/t1-legacy.log" 2>&1 || status_t1=1

while IFS=$'\t' read -r name descriptor; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  printf '%s\t%s\n' "$name" "$descriptor" > "$RUN/results/one-json.list"
  timeout --signal=TERM --kill-after=5s 120s \
    python3 ./vvp_reg.py "$RUN/results/one-json.list" \
    > "$RUN/results/t1-json-$name.log" 2>&1 || status_t1=1
done < ./regress-constraint-functions.list
if [[ $status_t1 -eq 0 ]]; then echo 'T1 constraint-function suites: PASS'; else echo 'T1 constraint-function suites: FAIL'; fi

[[ $status_t0 -eq 0 && $status_t1 -eq 0 ]]
