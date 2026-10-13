#!/usr/bin/env bash
#SBATCH --job-name=a3-dpi-probe
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=5G
#SBATCH --time=01:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01/logs/%x-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01
SRC="$RUN_DIR/source"
INSTALL="$RUN_DIR/install"
UVM="$RUN_DIR/input/uvm"
EXPECTED_SOURCE=db458c438eca253fb1b3110f671fe3800e33b7a0
EXPECTED_TREE=2cb6260f02c1680196cca51d76e6e429e3b738d5
UVM_ARCHIVE=/home/dsell/toolchains/uvm-sv-tests-656f20d-69ceddad024e4f04.tar.gz
UVM_SHA=69ceddad024e4f04b45aa2e96abf14bf1b027a8277a719920a63bbaccf2b5e5d
TEST="$RUN_DIR/input/uvm_files.sv"
TEST_SHA=b5e124466f7f2f9ee3139aa1000039eb15d74cfaf96cf5db8b0b40dd6ef4407b
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/input" "$RUN_DIR/evidence" "$INSTALL"
echo "$UVM_SHA  $UVM_ARCHIVE" | sha256sum -c -
echo "$TEST_SHA  $TEST" | sha256sum -c -
git clone --depth 1 --single-branch --branch main https://github.com/dsellerbrock/iverilog-uvm.git "$SRC" > "$RUN_DIR/logs/clone.log" 2>&1
actual_source=$(git -C "$SRC" rev-parse HEAD)
actual_tree=$(git -C "$SRC" rev-parse HEAD^{tree})
test "$actual_source" = "$EXPECTED_SOURCE"
test "$actual_tree" = "$EXPECTED_TREE"
printf 'source_commit=%s\nsource_tree=%s\n' "$actual_source" "$actual_tree" > "$RUN_DIR/logs/provenance.txt"
{ hostname; date -u; g++ --version | head -1; bison --version | head -1; flex --version | head -1; } > "$RUN_DIR/logs/environment.txt"
cd "$SRC"
autoconf
./configure --enable-libveriuser --prefix="$INSTALL" > "$RUN_DIR/logs/configure.log" 2>&1
make -j3 > "$RUN_DIR/logs/build.log" 2>&1
make install > "$RUN_DIR/logs/install.log" 2>&1
mkdir -p "$UVM"
tar -xzf "$UVM_ARCHIVE" -C "$UVM"
{ "$INSTALL/bin/iverilog" -V 2>&1 | head -2; sha256sum "$INSTALL/bin/iverilog"; } >> "$RUN_DIR/logs/environment.txt"
set +e
timeout --signal=TERM --kill-after=2s 120s "$INSTALL/bin/iverilog" -g2012 -o "$RUN_DIR/evidence/uvm_files.out" -I "$UVM/src" -I "$RUN_DIR/input" "$UVM/src/uvm_pkg.sv" "$TEST" > "$RUN_DIR/logs/focused.log" 2>&1
rc=$?
set -e
printf 'compile_rc=%s\n' "$rc" >> "$RUN_DIR/logs/provenance.txt"
if grep -F 'uvm_hdl.svh:77: syntax error' "$RUN_DIR/logs/focused.log"; then
  echo 'BASELINE_REPRODUCED' | tee "$RUN_DIR/evidence/result.txt"
else
  echo 'BASELINE_DID_NOT_MATCH' | tee "$RUN_DIR/evidence/result.txt"
  cat "$RUN_DIR/logs/focused.log"
  exit 2
fi
