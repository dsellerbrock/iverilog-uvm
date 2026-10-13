#!/usr/bin/env bash
#SBATCH --job-name=a3-svstart-198f-verified
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=01:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-start-198f-verified-20261013-02
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-start-198f-verified-20261013-02/logs/slurm-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-start-198f-verified-20261013-02
TOOLCHAIN=/home/dsell/toolchains/iverilog-13-198f0ab-d728a3d5d05c
ARCHIVE=/home/dsell/toolchains/sv-tests-c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7.tar.gz
EXPECTED_SOURCE=198f0abec3154a916d13730cee24549e24e076b0
EXPECTED_IVL=d728a3d5d05cb81375b367f76324dc7b19b2f2dec6041626c0dcf2aac9664c16
EXPECTED_VVP=3146652a6461678992534d98ebb453f32e5bcaeedb1eeba029f415c5f50b4526
OUT="$RUN_DIR/evidence/start"
TOOL_BIN="$OUT/runners/bin"
mkdir -p "$RUN_DIR/logs" "$OUT" "$TOOL_BIN" "$RUN_DIR/corpus/repo"
grep -Fx "source_commit=$EXPECTED_SOURCE" "$TOOLCHAIN/manifest.txt"
sha256sum "$TOOLCHAIN/bin/iverilog" "$TOOLCHAIN/bin/vvp" > "$RUN_DIR/logs/toolchain-sha256.txt"
echo "$EXPECTED_IVL  $TOOLCHAIN/bin/iverilog" | sha256sum -c -
echo "$EXPECTED_VVP  $TOOLCHAIN/bin/vvp" | sha256sum -c -
sha256sum "$ARCHIVE" > "$RUN_DIR/logs/corpus-archive.sha256"
echo "3924ac0ef31a1cd3d39bb6942b4b313b690468f9ae296210f6e9e3093b640ac5  $ARCHIVE" | sha256sum -c -
{
  cat "$TOOLCHAIN/manifest.txt"
  hostname
  date -u
  python3 --version
  "$TOOLCHAIN/bin/iverilog" -V 2>&1 | sed -n '1,2p'
  "$TOOLCHAIN/bin/vvp" -V 2>&1 | sed -n '1,2p'
} > "$RUN_DIR/logs/environment.txt"
mkdir -p "$TOOL_BIN"
printf '#!/bin/sh\nexec %s/bin/iverilog "$@"\n' "$TOOLCHAIN" > "$TOOL_BIN/iverilog"
printf '#!/bin/sh\nexec %s/bin/vvp "$@"\n' "$TOOLCHAIN" > "$TOOL_BIN/vvp"
chmod +x "$TOOL_BIN/iverilog" "$TOOL_BIN/vvp"
test "$(PATH="$TOOL_BIN:/usr/local/bin:/usr/bin:/bin" command -v iverilog)" = "$TOOL_BIN/iverilog"
test "$(PATH="$TOOL_BIN:/usr/local/bin:/usr/bin:/bin" command -v vvp)" = "$TOOL_BIN/vvp"
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
export PATH="$TOOL_BIN:$TOOLCHAIN/bin:$PATH"
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH="$TOOLCHAIN/lib:$LD_LIBRARY_PATH"
else
  export LD_LIBRARY_PATH="$TOOLCHAIN/lib"
fi
python3 "$RUN_DIR/run_icarus_svtests.py" \
  --sv-tests "$ROOT" \
  --evidence "$OUT" \
  --runner-safe "$RUN_DIR/runner-safe" \
  --python-bin /usr/bin/python3 | tee "$RUN_DIR/logs/summary.log"
test "$(find "$OUT/out/logs/Icarus" -type f -name '*.log' | wc -l)" -eq 1027
tar -czf "$OUT/raw-logs.tar.gz" -C "$OUT/out/logs" Icarus
sha256sum "$OUT/raw-logs.tar.gz" > "$OUT/raw-logs.tar.gz.sha256"
echo 'SVTESTS_START_PASS'
