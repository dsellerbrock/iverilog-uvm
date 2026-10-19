#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-438-t0t1-r3
#SBATCH --cpus-per-task=3
#SBATCH --mem=8G
#SBATCH --time=02:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/issue438-t0t1-20261019-r3/source
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue438-t0t1-20261019-r3/logs/%x-%j.out
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue438-t0t1-20261019-r3
SRC=$RUN/source
PREFIX=$SRC/local-install
LOGS=$RUN/logs
RESULTS=$RUN/results
UVM_SHARED=/home/dsell/toolchains/iverilog-uvm-d9caaaea5b410ed14e7ca14be828fc2f2c9fea44-a5-wp6-r2/lib/ivl/uvm
finish() {
  rc=$?
  trap - EXIT
  printf 'exit=%s\nfinished=%s\n' "$rc" "$(date -Is)" > "$RESULTS/result.txt"
  exit "$rc"
}
trap finish EXIT
mkdir -p "$LOGS" "$RESULTS"
printf 'job_id=%s\nhost=%s\nstarted=%s\nsource_commit=79c20c387f9f7f267049a9154710d3395b5bef6d\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" > "$RESULTS/run-meta.txt"
test "$(sha256sum "$UVM_SHARED/src/uvm_pkg.sv" | cut -d' ' -f1)" = 4c1516f91172fc24e9d8f023911ffcb5718da281f285f3062547553c09be60e6
mkdir -p "$SRC/uvm-core"
rmdir "$SRC/uvm-core"
ln -s "$UVM_SHARED" "$SRC/uvm-core"
printf 'uvm_core_shared=%s\n' "$UVM_SHARED" >> "$RESULTS/run-meta.txt"
cd "$SRC"
autoconf
./configure --prefix="$PREFIX" --enable-libveriuser
/usr/bin/time -v make -j"${SLURM_CPUS_PER_TASK:-3}" > "$LOGS/build.log" 2>&1
/usr/bin/time -v make check > "$LOGS/make-check.log" 2>&1
/usr/bin/time -v make install > "$LOGS/install.log" 2>&1
export PATH="$PREFIX/bin:$PATH"
printf 'iverilog=%s\nvvp=%s\n' "$(command -v iverilog)" "$(command -v vvp)" >> "$RESULTS/run-meta.txt"
sha256sum "$(command -v iverilog)" "$(command -v vvp)" > "$RESULTS/toolchain.sha256"

pattern='^(sv_clocking_(unpacked_output_storage(_2023)?|selected_decl_assign_target(_2023)?|param_if_width_(2017|2023)|unpacked_output_bad_pattern_fail(_2017|_2023)?|output_continuous_alias_overlap(_2017|_2023)?)|sv_vif_clocking_selected_decl_assign_target(_2023)?)$'
awk -v re="$pattern" '$1 ~ re { print }' "$SRC/ivtest/regress-sv.list" > "$RESULTS/t0-issue-legacy.list"
awk -v re="$pattern" '$1 ~ re { print }' "$SRC/ivtest/regress-vvp.list" > "$RESULTS/t0-issue-json.list"
legacy_count=$(wc -l < "$RESULTS/t0-issue-legacy.list")
json_count=$(wc -l < "$RESULTS/t0-issue-json.list")
printf 't0_legacy_cases=%s\nt0_json_cases=%s\n' "$legacy_count" "$json_count" >> "$RESULTS/run-meta.txt"
test "$legacy_count" -eq 11
test "$json_count" -eq 12
cd "$SRC/ivtest"
set +e
timeout --signal=TERM --kill-after=10s 1800s perl vvp_reg.pl "$RESULTS/t0-issue-legacy.list" > "$LOGS/t0-issue-legacy.log" 2>&1
legacy_rc=$?
set -e
test "$legacy_rc" -eq 0
: > "$RESULTS/t0-issue-json-status.tsv"
while IFS= read -r row; do
  key=$(awk '{print $1}' <<< "$row")
  one="$RESULTS/$key.list"
  printf '%s\n' "$row" > "$one"
  set +e
  timeout --signal=TERM --kill-after=5s 180s python3 vvp_reg.py "$one" > "$LOGS/t0-json-$key.log" 2>&1
  rc=$?
  set -e
  printf '%s\t%s\n' "$key" "$rc" >> "$RESULTS/t0-issue-json-status.tsv"
  test "$rc" -eq 0
done < "$RESULTS/t0-issue-json.list"
cd "$SRC"
set +e
timeout --signal=TERM --kill-after=15s 5400s bash ci/run-smoke.sh > "$LOGS/t0-smoke.log" 2>&1
smoke_rc=$?
set -e
test "$smoke_rc" -eq 0

cp "$SRC/ivtest/regress-vif-clocking-output-focus-legacy.list" "$RESULTS/t1-legacy.list"
cp "$SRC/ivtest/regress-vif-clocking-output-focus-vvp.list" "$RESULTS/t1-json.list"
if ! awk '$1 == "sv_clocking_output_continuous_alias_overlap" { found=1 } END { exit !found }' "$RESULTS/t1-legacy.list"; then
  awk '$1 == "sv_clocking_output_continuous_alias_overlap" { print }' "$SRC/ivtest/regress-sv.list" >> "$RESULTS/t1-legacy.list"
fi
for key in sv_clocking_output_continuous_alias_overlap_2017 sv_clocking_output_continuous_alias_overlap_2023; do
  if ! awk -v k="$key" '$1 == k { found=1 } END { exit !found }' "$RESULTS/t1-json.list"; then
    awk -v k="$key" '$1 == k { print }' "$SRC/ivtest/regress-vvp.list" >> "$RESULTS/t1-json.list"
  fi
done
printf 't1_legacy_cases=%s\nt1_json_cases=%s\n' "$(wc -l < "$RESULTS/t1-legacy.list")" "$(wc -l < "$RESULTS/t1-json.list")" >> "$RESULTS/run-meta.txt"
cd "$SRC/ivtest"
set +e
timeout --signal=TERM --kill-after=10s 5400s perl vvp_reg.pl "$RESULTS/t1-legacy.list" > "$LOGS/t1-legacy.log" 2>&1
t1_legacy_rc=$?
set -e
test "$t1_legacy_rc" -eq 0
: > "$RESULTS/t1-json-status.tsv"
while IFS= read -r row; do
  case "$row" in ''|\#*) continue ;; esac
  key=$(awk '{print $1}' <<< "$row")
  one="$RESULTS/$key.list"
  printf '%s\n' "$row" > "$one"
  set +e
  timeout --signal=TERM --kill-after=5s 180s python3 vvp_reg.py "$one" > "$LOGS/t1-json-$key.log" 2>&1
  rc=$?
  set -e
  printf '%s\t%s\n' "$key" "$rc" >> "$RESULTS/t1-json-status.tsv"
  test "$rc" -eq 0
done < "$RESULTS/t1-json.list"
printf 'T0=PASS\nT1=PASS\n' > "$RESULTS/DONE"
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/run-meta.txt"
cat "$RESULTS/run-meta.txt"
