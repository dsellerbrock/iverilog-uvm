#!/usr/bin/env bash
#SBATCH --job-name=a5-wp9-caliptra-r2
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019-caliptra-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019-caliptra-r2/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019-caliptra-r2
BUILT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
INPUT=$ROOT/input
SOURCE=$BUILT/source
INSTALL=$BUILT/install
RESULTS=$ROOT/results
LOGS=$ROOT/logs
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
CALIPTRA=/home/dsell/toolchains/iverilog-c339
RTL=$CALIPTRA/firmware/caliptra-rtl
ENV=$CALIPTRA/deps
OPENSSL=$CALIPTRA/openssl
GCC_DIR=$CALIPTRA/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
JTAG_VPI=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf/caliptra-jtagdpi/jtagdpi.vpi
RUNNER=$INPUT/caliptra/run_caliptra_top_profile.py
START=100
END=2100
CPU=$(awk '/Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
mkdir -p "$ROOT"/{input,results,logs,window,caliptra/{out,logs}}
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
(cd "$INPUT" && sha256sum --check SHA256SUMS) > "$RESULTS/input-checksums.txt"
(cd "$INPUT/caliptra" && sha256sum --check SHA256SUMS) \
  >> "$RESULTS/input-checksums.txt"
printf '%s\n' "$BASE" > "$SOURCE/source.commit"
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
test -z "$(git -C "$RTL" status --porcelain --untracked-files=all)"
test -z "$(git -C "$RTL/submodules/adams-bridge" status --porcelain --untracked-files=all)"
(
  cd "$ROOT/window"
  "$INSTALL/bin/iverilog-vpi" "$INPUT/caliptra/mcycle-window-vpi.c"
) > "$LOGS/window-plugin.log" 2>&1
test -s "$ROOT/window/mcycle-window-vpi.vpi"
export PATH="$INSTALL/bin:$ENV/bin:$GCC_DIR:$OPENSSL/bin:/usr/bin:/bin"
export LD_LIBRARY_PATH="$INSTALL/lib:$ENV/lib:$OPENSSL/lib"
export CALIPTRA_BFM_REPO=$QD CALIPTRA_MBEDTLS_ROOT=$ENV CALIPTRA_RTL=$RTL
export CALIPTRA_GCC_PREFIX=$GCC_DIR/riscv-none-elf- CALIPTRA_JTAGDPI_VPI=$JTAG_VPI
export CALIPTRA_BFM_PROFILE=$RTL/src/integration/config/caliptra_top_tb.vf
export CALIPTRA_PRIM_ROOT=$RTL/src/caliptra_prim_generic
export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
export IVERILOG_BIN=$INSTALL/bin/iverilog IVERILOG_VPI_BIN=$INSTALL/bin/iverilog-vpi
export IVERILOG_SOURCE_ROOT=$SOURCE UVM_DPI=$INSTALL/lib/ivl/uvm_dpi.vpi
export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$ROOT/window/mcycle-window-vpi.vpi
export CALIPTRA_MCYCLE_WINDOW_START=$START CALIPTRA_MCYCLE_WINDOW_END=$END
export A5_FIXED_ECC_SOURCE=$INPUT/caliptra/ecc_secp384r1-deterministic.c
export VVP_BIN=$INSTALL/bin/vvp IVL_PERF_STATS=1 LC_ALL=C
printf 'source_commit=%s\nwindow=%s:%s\ncpu=%s\n' "$BASE" "$START" "$END" "$CPU" > "$RESULTS/provenance.txt"
for case_name in smoke_test_dma_aes_gcm_short_1_dword smoke_test_sha256 cptra_ss_test_rom; do
  out=$ROOT/caliptra/out/$case_name
  evidence=$ROOT/caliptra/logs/$case_name
  mkdir -p "$evidence"
  set +e
  /usr/bin/time -v -o "$evidence/resource.txt" \
    timeout --signal=INT --kill-after=60s 1800s taskset -c "$CPU" \
    "$ENV/bin/python3.12" "$RUNNER" --case "$case_name" \
    --case-yaml "$case_name/$case_name.yml" --output "$out" \
    > "$evidence/runner.log" 2>&1
  rc=$?
  set -e
  test "$rc" -eq 1
  sim_log=$out/$case_name/sim.log
  marker=$(grep '^MCYCLE_WINDOW ' "$sim_log")
  grep -Eq "^MCYCLE_WINDOW start=$START end=$END cycles=$((END-START)) elapsed_ns=[1-9][0-9]*$" <<< "$marker"
  cp "$sim_log" "$evidence/sim.log"
  find "$out" -type f -name '*.hex' -print0 | sort -z | xargs -0 -r sha256sum > "$evidence/generated-hex.sha256"
  printf '%s\t%s\n' "$case_name" "$marker" >> "$RESULTS/window-markers.tsv"
  rm -rf "$out"
done
python3 "$INPUT/caliptra/extract_stats.py" "$ROOT/caliptra" > "$LOGS/extract-stats.log" 2>&1
cp "$ROOT/caliptra/scheduler-counters.csv" "$RESULTS/"
cp "$ROOT/caliptra/scheduler-counters.json" "$RESULTS/"
sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" "$INSTALL/bin/iverilog-vpi" \
  "$INSTALL/lib/ivl/uvm_dpi.vpi" "$INPUT/caliptra/mcycle-window-vpi.c" \
  "$INPUT/caliptra/ecc_secp384r1-deterministic.c" > "$RESULTS/binaries-inputs.sha256"
find "$RESULTS" "$ROOT/caliptra/logs" -type f -print0 | sort -z \
  | xargs -0 sha256sum > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
