#!/usr/bin/env bash
#SBATCH --job-name=a3-457-step7c
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=5G
#SBATCH --time=00:40:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/issue457-step7-20261017-attempt03/logs/%x-%j.out
set -uo pipefail
WORK=/home/dsell/slurm-runs/iverilog-uvm/a3/issue457-step6-20261017-attempt02
SRC="$WORK/src"
PREFIX="$SRC/local-install"
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/issue457-step7-20261017-attempt03
mkdir -p "$RUN/logs"
cd "$SRC"
status=0

{
  echo "host=$(hostname)"
  date -Is
  echo "base=$(cat "$WORK/base.txt")"
  echo "source_snapshot=$(cat "$WORK/source.sha256")"
  echo "overlay_snapshot=$(cat "$WORK/overlay.sha256")"
  echo "resources=3 CPUs, 5 GiB, 40 minutes"
  sha256sum pform_pclass.cc vvp/vthread.cc
} > "$RUN/logs/results.txt"

if ! ./configure --prefix="$PREFIX" > "$RUN/logs/configure.log" 2>&1; then
  echo 'configure=FAIL' >> "$RUN/logs/results.txt"
  exit 1
fi
if ! make -j3 > "$RUN/logs/make.log" 2>&1; then
  echo 'build=FAIL' >> "$RUN/logs/results.txt"
  exit 1
fi
if ! make install > "$RUN/logs/install.log" 2>&1; then
  echo 'install=FAIL' >> "$RUN/logs/results.txt"
  exit 1
fi
echo 'build=PASS' >> "$RUN/logs/results.txt"
sha256sum "$PREFIX/bin/iverilog" "$PREFIX/bin/vvp" >> "$RUN/logs/results.txt"
export PATH="$PREFIX/bin:$PATH"
python3 tests/vvp_runtime/run_covgrp_exports.py >> "$RUN/logs/results.txt" 2>&1

cd "$SRC/ivtest"
grep -E '^sv_covergroup_class_inheritance_(2017|2023|missing_base_2023)[[:space:]]' regress-sv.list > "$RUN/focused-sv.list"
if perl ./vvp_reg.pl "$RUN/focused-sv.list" > "$RUN/logs/focused-sv.log" 2>&1; then
  echo 'focused_legacy=PASS' >> "$RUN/logs/results.txt"
else
  echo 'focused_legacy=FAIL' >> "$RUN/logs/results.txt"
  status=1
fi
grep -E '^sv_covergroup_class_inheritance_(2017|2023|missing_base_2023)[[:space:]]' regress-vvp.list > "$RUN/focused-json.list"
if timeout -k 2s 300s python3 ./vvp_reg.py "$RUN/focused-json.list" > "$RUN/logs/focused-json.log" 2>&1; then
  echo 'focused_json=PASS' >> "$RUN/logs/results.txt"
else
  echo 'focused_json=FAIL' >> "$RUN/logs/results.txt"
  status=1
fi

cd "$SRC"
if timeout -k 2s 1800s bash ci/run-smoke.sh > "$RUN/logs/smoke.log" 2>&1; then
  echo 'smoke=PASS' >> "$RUN/logs/results.txt"
else
  echo 'smoke=FAIL' >> "$RUN/logs/results.txt"
  status=1
fi

cd "$SRC/ivtest"
awk 'tolower($1) ~ /covergroup/ || tolower($2) ~ /covergroup/' regress-sv.list > "$RUN/t1-covergroup-sv.list"
legacy_count=$(wc -l < "$RUN/t1-covergroup-sv.list")
echo "t1_legacy_cases=$legacy_count" >> "$RUN/logs/results.txt"
if timeout -k 2s 1800s perl ./vvp_reg.pl "$RUN/t1-covergroup-sv.list" > "$RUN/logs/t1-legacy.log" 2>&1; then
  echo 't1_legacy=PASS' >> "$RUN/logs/results.txt"
else
  echo 't1_legacy=FAIL' >> "$RUN/logs/results.txt"
  status=1
fi
awk 'tolower($1) ~ /covergroup/ || tolower($2) ~ /covergroup/' regress-vvp.list > "$RUN/t1-covergroup-json.list"
json_count=$(wc -l < "$RUN/t1-covergroup-json.list")
json_failures=0
: > "$RUN/logs/t1-json.log"
while IFS= read -r testcase; do
  printf '%s\n' "$testcase" > "$RUN/one-json.list"
  if ! timeout -k 2s 120s python3 ./vvp_reg.py "$RUN/one-json.list" >> "$RUN/logs/t1-json.log" 2>&1; then
    json_failures=$((json_failures + 1))
  fi
done < "$RUN/t1-covergroup-json.list"
echo "t1_json_cases=$json_count" >> "$RUN/logs/results.txt"
echo "t1_json_failures=$json_failures" >> "$RUN/logs/results.txt"
if [ "$json_failures" -eq 0 ]; then
  echo 't1_json=PASS' >> "$RUN/logs/results.txt"
else
  echo 't1_json=FAIL' >> "$RUN/logs/results.txt"
  status=1
fi

cat "$RUN/logs/focused-sv.log" >> "$RUN/logs/results.txt"
cat "$RUN/logs/focused-json.log" >> "$RUN/logs/results.txt"
tail -80 "$RUN/logs/smoke.log" >> "$RUN/logs/results.txt"
cat "$RUN/logs/t1-legacy.log" >> "$RUN/logs/results.txt"
tail -100 "$RUN/logs/t1-json.log" >> "$RUN/logs/results.txt"
exit "$status"
