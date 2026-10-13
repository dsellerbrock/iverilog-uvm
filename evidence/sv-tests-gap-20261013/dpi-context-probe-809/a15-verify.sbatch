#!/usr/bin/env bash
#SBATCH --job-name=a3-dpi-a15
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=5G
#SBATCH --time=00:45:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-a15-verify-20261013-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-a15-verify-20261013-01/logs/%x-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-a15-verify-20261013-01
SRC="$RUN_DIR/source"
INSTALL="$RUN_DIR/install"
UVM="$RUN_DIR/input/uvm"
TEST="$RUN_DIR/input/16.10--property-local-var-uvm.sv"
ARCHIVE=/home/dsell/toolchains/uvm-sv-tests-656f20d-69ceddad024e4f04.tar.gz
EXPECTED_SOURCE=a15ae5be50b3b782c2590711cc4861a01ef11f6c
EXPECTED_TREE=2cb6260f02c1680196cca51d76e6e429e3b738d5
TEST_SHA=43f638a3f06492a85ae183b3290b4116fad35802b891cdfde4bdf1f8a9a24a1a
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/evidence" "$RUN_DIR/input" "$INSTALL"
echo "$TEST_SHA  $TEST" | sha256sum -c -
git clone --depth 1 --single-branch --branch batch/2026-10-13-10 https://github.com/dsellerbrock/iverilog-uvm.git "$SRC" > "$RUN_DIR/logs/clone.log" 2>&1
git -C "$SRC" submodule update --init --recursive >> "$RUN_DIR/logs/clone.log" 2>&1
test "$(git -C "$SRC" rev-parse HEAD)" = "$EXPECTED_SOURCE"
test "$(git -C "$SRC" rev-parse HEAD^{tree})" = "$EXPECTED_TREE"
cd "$SRC"
autoconf
./configure --enable-libveriuser --prefix="$INSTALL" > "$RUN_DIR/logs/configure.log" 2>&1
make -j3 > "$RUN_DIR/logs/build.log" 2>&1
make install > "$RUN_DIR/logs/install.log" 2>&1
mkdir -p "$UVM"
tar -xzf "$ARCHIVE" -C "$UVM"
{
  hostname
  date -u
  g++ --version | sed -n '1p'
  bison --version | sed -n '1p'
  flex --version | sed -n '1p'
  "$INSTALL/bin/iverilog" -V 2>&1 | sed -n '1,2p'
  sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp"
} > "$RUN_DIR/logs/environment.txt"
set +e
timeout --signal=TERM --kill-after=2s 120s "$INSTALL/bin/iverilog" -g2012 -o "$RUN_DIR/evidence/property-local-var-uvm.out" -I "$UVM/src" -I "$RUN_DIR/input" "$UVM/src/uvm_pkg.sv" "$TEST" > "$RUN_DIR/logs/focused.log" 2>&1
rc=$?
set -e
printf 'case_compile_rc=%s\n' "$rc" | tee "$RUN_DIR/evidence/result.txt"
cat "$RUN_DIR/logs/focused.log"
