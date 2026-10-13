#!/usr/bin/env bash
#SBATCH --job-name=a3-svtests-end
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=5G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-end-20261013-02
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-end-20261013-02/logs/slurm-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-end-20261013-02
SRC="$RUN_DIR/source"
INSTALL="$RUN_DIR/install"
ARCHIVE=/home/dsell/toolchains/sv-tests-c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7.tar.gz
EXPECTED_SOURCE=a15ae5be50b3b782c2590711cc4861a01ef11f6c
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/evidence" "$INSTALL" "$RUN_DIR/corpus/repo"
sha256sum "$ARCHIVE" > "$RUN_DIR/logs/corpus-archive.sha256"
echo "3924ac0ef31a1cd3d39bb6942b4b313b690468f9ae296210f6e9e3093b640ac5  $ARCHIVE" | sha256sum -c -
git clone --depth 1 --single-branch --branch batch/2026-10-13-10 https://github.com/dsellerbrock/iverilog-uvm.git "$SRC" > "$RUN_DIR/logs/clone.log" 2>&1
git -C "$SRC" submodule update --init --recursive >> "$RUN_DIR/logs/clone.log" 2>&1
actual_source=$(git -C "$SRC" rev-parse HEAD)
test "$actual_source" = "$EXPECTED_SOURCE"
{
  echo "source_commit=$actual_source"
  git -C "$SRC" submodule status
  hostname
  date -u
  g++ --version | sed -n '1p'
  autoconf --version | sed -n '1p'
  pkg-config --modversion z3 2>/dev/null || true
} > "$RUN_DIR/logs/environment.txt"
cd "$SRC"
autoconf
./configure --enable-libveriuser --prefix="$INSTALL" > "$RUN_DIR/logs/configure.log" 2>&1
make -j3 > "$RUN_DIR/logs/build.log" 2>&1
make install > "$RUN_DIR/logs/install.log" 2>&1
tar -xzf "$ARCHIVE" -C "$RUN_DIR/corpus/repo"
ROOT="$RUN_DIR/corpus/repo"
UVM="$ROOT/third_party/tests/uvm"
git -C "$UVM" init -q
git -C "$UVM" add -f .
git -C "$UVM" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Pinned UVM evidence snapshot'
uvm_sha=$(git -C "$UVM" rev-parse HEAD)
git -C "$ROOT" init -q
git -C "$ROOT" add -f tests conf tools
printf 'sv-tests=c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7\nuvm=656f20d087370a7c742e00188d20bbf30fa95339\n' > "$RUN_DIR/logs/provenance.txt"
git -C "$ROOT" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Pinned sv-tests test and runner snapshot'
git -C "$ROOT" update-index --add --cacheinfo "160000,$uvm_sha,third_party/tests/uvm"
git -C "$ROOT" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Record pinned UVM snapshot'
printf 'synthetic_uvm=%s\n' "$uvm_sha" >> "$RUN_DIR/logs/provenance.txt"
mkdir -p "$RUN_DIR/tool-bin"
printf '#!/bin/sh\nexec %s/bin/iverilog "$@"\n' "$INSTALL" > "$RUN_DIR/tool-bin/iverilog"
printf '#!/bin/sh\nexec %s/bin/vvp "$@"\n' "$INSTALL" > "$RUN_DIR/tool-bin/vvp"
chmod +x "$RUN_DIR/tool-bin/iverilog" "$RUN_DIR/tool-bin/vvp"
{
  hostname
  python3 --version
  "$INSTALL/bin/iverilog" -V 2>&1 | sed -n '1,2p'
  "$INSTALL/bin/vvp" -V 2>&1 | sed -n '1,2p'
  sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp"
} >> "$RUN_DIR/logs/environment.txt"
export PATH="$RUN_DIR/tool-bin:$INSTALL/bin:$PATH"
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH="$INSTALL/lib:$LD_LIBRARY_PATH"
else
  export LD_LIBRARY_PATH="$INSTALL/lib"
fi
python3 "$RUN_DIR/run_icarus_svtests.py" \
  --sv-tests "$ROOT" \
  --evidence "$RUN_DIR/evidence/batch-10" \
  --runner-safe "$RUN_DIR/runner-safe" \
  --python-bin /usr/bin/python3 | tee "$RUN_DIR/logs/summary.log"
echo 'SVTESTS_END_PASS'
