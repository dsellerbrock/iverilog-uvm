#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
RUN_DIR=/tmp/a3-m7-svtests-20261021-02
SRC="$RUN_DIR/source"
INSTALL="$RUN_DIR/install"
ARCHIVE=/tmp/a3-m7-svtests-c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7.tar.gz
EXPECTED_SOURCE=10f3a0a2509d0852c2556cb6622fb0025121fb2d
EXPECTED_TREE=865b68d3317a817fab97961dec52f4bdc7e41568
EXPECTED_CORPUS=c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7
EXPECTED_CORPUS_SHA=3924ac0ef31a1cd3d39bb6942b4b313b690468f9ae296210f6e9e3093b640ac5
EXPECTED_UVM=656f20d087370a7c742e00188d20bbf30fa95339
OUT="$RUN_DIR/evidence"
TOOL_BIN="$OUT/runners/bin"

sha256sum() { command shasum -a 256 "$@"; }

mkdir -p "$RUN_DIR/logs" "$RUN_DIR/results" "$OUT" "$TOOL_BIN" "$INSTALL" "$RUN_DIR/corpus/repo"
cp "$SCRIPT_DIR/run_icarus_svtests.py" "$RUN_DIR/"
cp "$SCRIPT_DIR/runner-safe" "$RUN_DIR/"
sha256sum "$ARCHIVE" > "$RUN_DIR/logs/corpus-archive.sha256"
echo "$EXPECTED_CORPUS_SHA  $ARCHIVE" | sha256sum -c -

git init -q "$SRC"
git -C "$SRC" remote add origin https://github.com/dsellerbrock/iverilog-uvm.git
git -C "$SRC" fetch --depth=1 origin "$EXPECTED_SOURCE" > "$RUN_DIR/logs/clone.log" 2>&1
git -C "$SRC" checkout --detach FETCH_HEAD >> "$RUN_DIR/logs/clone.log" 2>&1
actual_source=$(git -C "$SRC" rev-parse HEAD)
actual_tree=$(git -C "$SRC" rev-parse 'HEAD^{tree}')
test "$actual_source" = "$EXPECTED_SOURCE"
test "$actual_tree" = "$EXPECTED_TREE"
git -C "$SRC" submodule update --init --recursive >> "$RUN_DIR/logs/clone.log" 2>&1
{
  echo "source_commit=$actual_source"
  echo "source_tree=$actual_tree"
  git -C "$SRC" submodule status
  hostname
  date -u
  sw_vers
  g++ --version | sed -n '1p'
  /opt/homebrew/opt/bison/bin/bison --version | sed -n '1p'
  /usr/bin/python3 --version
} > "$RUN_DIR/logs/environment.txt"

cd "$SRC"
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
autoconf > "$RUN_DIR/logs/autoconf.log" 2>&1
YACC=/opt/homebrew/opt/bison/bin/bison ./configure --enable-libveriuser --prefix="$INSTALL" > "$RUN_DIR/logs/configure.log" 2>&1
make -j3 > "$RUN_DIR/logs/build.log" 2>&1
make install > "$RUN_DIR/logs/install.log" 2>&1
{
  "$INSTALL/bin/iverilog" -V 2>&1 | sed -n '1,2p'
  "$INSTALL/bin/vvp" -V 2>&1 | sed -n '1,2p'
  sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp"
} >> "$RUN_DIR/logs/environment.txt"

tar -xzf "$ARCHIVE" -C "$RUN_DIR/corpus/repo"
ROOT="$RUN_DIR/corpus/repo"
UVM="$ROOT/third_party/tests/uvm"
# The corpus archive SHA pins the extracted UVM tree; the tarball has no .git metadata.
git -C "$UVM" init -q
git -C "$UVM" add -f .
git -C "$UVM" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Pinned UVM evidence snapshot'
uvm_sha=$(git -C "$UVM" rev-parse HEAD)
git -C "$ROOT" init -q
git -C "$ROOT" add -f tests conf tools
printf 'sv-tests=%s\nuvm=%s\n' "$EXPECTED_CORPUS" "$EXPECTED_UVM" > "$RUN_DIR/logs/provenance.txt"
git -C "$ROOT" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Pinned sv-tests test and runner snapshot'
git -C "$ROOT" update-index --add --cacheinfo "160000,$uvm_sha,third_party/tests/uvm"
git -C "$ROOT" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Record pinned UVM snapshot'
printf 'synthetic_uvm=%s\n' "$uvm_sha" >> "$RUN_DIR/logs/provenance.txt"

printf '#!/bin/sh\nexec %s/bin/iverilog "$@"\n' "$INSTALL" > "$TOOL_BIN/iverilog"
printf '#!/bin/sh\nexec %s/bin/vvp "$@"\n' "$INSTALL" > "$TOOL_BIN/vvp"
chmod +x "$TOOL_BIN/iverilog" "$TOOL_BIN/vvp"
test "$(PATH="$TOOL_BIN:/usr/local/bin:/usr/bin:/bin" command -v iverilog)" = "$TOOL_BIN/iverilog"
test "$(PATH="$TOOL_BIN:/usr/local/bin:/usr/bin:/bin" command -v vvp)" = "$TOOL_BIN/vvp"
export PATH="$TOOL_BIN:$INSTALL/bin:$PATH"
export DYLD_LIBRARY_PATH="$INSTALL/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
{
  echo "runner_iverilog_wrapper=$TOOL_BIN/iverilog"
  echo "runner_vvp_wrapper=$TOOL_BIN/vvp"
  sha256sum "$TOOL_BIN/iverilog" "$TOOL_BIN/vvp"
} >> "$RUN_DIR/logs/environment.txt"

python3 "$RUN_DIR/run_icarus_svtests.py" \
  --sv-tests "$ROOT" \
  --evidence "$OUT" \
  --runner-safe "$RUN_DIR/runner-safe" \
  --python-bin /usr/bin/python3 | tee "$RUN_DIR/logs/summary.log"

cp "$OUT/summary.json" "$RUN_DIR/results/summary.json"
cp "$OUT/all-tests.txt" "$RUN_DIR/results/all-tests.txt"
tar -czf "$RUN_DIR/results/current-raw-logs.tar.gz" -C "$OUT/out/logs" Icarus
sha256sum "$RUN_DIR/results/summary.json" "$RUN_DIR/results/all-tests.txt" "$RUN_DIR/results/current-raw-logs.tar.gz" > "$RUN_DIR/results/SHA256SUMS"
printf 'SVTESTS_END_PASS\n' > "$RUN_DIR/results/status.txt"
