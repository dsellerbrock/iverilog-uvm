#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-t2-batch22-1
#SBATCH --cpus-per-task=4
#SBATCH --mem=6G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/t2-batch-20261022-1/source
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/t2-batch-20261022-1/logs/%x-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/t2-batch-20261022-1
SRC="$RUN_DIR/source"
PREFIX="$SRC/local-install"
UVM_SHARED=/home/dsell/toolchains/iverilog-uvm-d9caaaea5b410ed14e7ca14be828fc2f2c9fea44-a5-wp6-r2/lib/ivl/uvm
finish() {
  rc=$?
  trap - EXIT
  printf 'exit=%s\nfinished=%s\n' "$rc" "$(date -Is)" > "$RUN_DIR/results/script.exit"
  exit "$rc"
}
trap finish EXIT
mkdir -p "$SRC" "$RUN_DIR/results"
archive_sha=$(sha256sum "$RUN_DIR/source.tar.gz" | cut -d' ' -f1)
printf 'source_archive_sha256=%s\n' "$archive_sha"
test "$archive_sha" = c911c782fc9fb56e5d82b0d2cd9a2448862d2310359b44d0611175511fe39b7d
tar -xzf "$RUN_DIR/source.tar.gz" -C "$SRC"
printf 'job_id=%s\nhost=%s\nstarted=%s\nbatch_commit=18132be37631a9d07957b483ee0c9d5843f01349\nmain_base=e90fcc1776f6022ce058388402738be7bf7218a6\nprs=827,904,934\npr_827=52c1df44155d313cb04c85d077df5d597c71ed97\npr_904=c7c27c24fb369a0d8af148baddf1626a8b7af6cd\npr_934=745eeeeb51a0f6003d05c086281b6e077d87217b\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" > "$RUN_DIR/results/metadata.txt"
test -d "$UVM_SHARED"
test "$(sha256sum "$UVM_SHARED/src/uvm_pkg.sv" | cut -d' ' -f1)" = 4c1516f91172fc24e9d8f023911ffcb5718da281f285f3062547553c09be60e6
if test -d "$SRC/uvm-core"; then rmdir "$SRC/uvm-core"; fi
ln -s "$UVM_SHARED" "$SRC/uvm-core"
printf 'uvm_core_shared=%s\nuvm_pkg_sha256=%s\n' "$UVM_SHARED" "$(sha256sum "$SRC/uvm-core/src/uvm_pkg.sv" | cut -d' ' -f1)" >> "$RUN_DIR/results/metadata.txt"
sh autoconf.sh
./configure --prefix="$PREFIX" --enable-libveriuser
/usr/bin/time -v make -j"${SLURM_CPUS_PER_TASK:-4}"
/usr/bin/time -v make check
/usr/bin/time -v make install
export PATH="$PREFIX/bin:$PATH"
printf 'iverilog=%s\nvvp=%s\n' "$(command -v iverilog)" "$(command -v vvp)" >> "$RUN_DIR/results/metadata.txt"
sha256sum "$(command -v iverilog)" "$(command -v vvp)" >> "$RUN_DIR/results/metadata.txt"
/usr/bin/time -v bash .github/ivtest_gate.sh
/usr/bin/time -v bash .github/ivtest_focus_gate.sh regress-vif-function-focus-legacy.list regress-vif-function-focus-vvp.list
/usr/bin/time -v bash .github/ivtest_focus_gate.sh regress-vif-parameter-specialization-focus-legacy.list regress-vif-parameter-specialization-focus-vvp.list
/usr/bin/time -v bash .github/uvm_test.sh
/usr/bin/time -v bash .github/uvm_frontend_test.sh
/usr/bin/time -v env IVERILOG="$(command -v iverilog)" IVPI="$(command -v iverilog-vpi)" VVP="$SRC/vvp/vvp" DPI_CHAR_CFLAGS=-funsigned-char bash tests/vvp_runtime/run_dpi_plain_char_abi.sh
printf 'T2_full_gate=PASS\n' > "$RUN_DIR/results/T2_full_gate.txt"
