#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"
RUN_DIR="${1:?usage: local-run.sh RUN_DIR}"
SRC="$RUN_DIR/source"
INSTALL="$RUN_DIR/install"
CORPUS="$WORKSPACE/clean-corpora/sv-tests-c4229f3"
DPI_MODULE_DIR="$RUN_DIR/dpi-module"
EXPECTED_SOURCE=db458c438eca253fb1b3110f671fe3800e33b7a0
EXPECTED_TREE=2cb6260f02c1680196cca51d76e6e429e3b738d5

mkdir -p "$RUN_DIR/logs" "$RUN_DIR/corpus" "$RUN_DIR/evidence" "$INSTALL" "$DPI_MODULE_DIR"
test "$(git -C "$CORPUS" rev-parse HEAD)" = c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7
test "$(git -C "$CORPUS/third_party/tests/uvm" rev-parse HEAD)" = 656f20d087370a7c742e00188d20bbf30fa95339
ln -s "$CORPUS" "$RUN_DIR/corpus/repo"

git clone --shared "$ROOT" "$SRC" > "$RUN_DIR/logs/clone.log" 2>&1
git -C "$SRC" checkout --detach "$EXPECTED_SOURCE" >> "$RUN_DIR/logs/clone.log" 2>&1
git -C "$SRC" submodule update --init --recursive >> "$RUN_DIR/logs/clone.log" 2>&1
test "$(git -C "$SRC" rev-parse HEAD)" = "$EXPECTED_SOURCE"
test "$(git -C "$SRC" rev-parse 'HEAD^{tree}')" = "$EXPECTED_TREE"
cp -a "$CORPUS/tests" "$RUN_DIR/evidence/tests"
cp "$HERE/run_uvm_subset.py" "$RUN_DIR/run_uvm_subset.py"
cp "$HERE/manifest.json" "$RUN_DIR/manifest.json"

export PATH="/opt/homebrew/opt/bison/bin:$PATH"
LIBFFI_PREFIX="$(brew --prefix libffi)"
Z3_PREFIX="$(brew --prefix z3)"
export CPPFLAGS="${CPPFLAGS:-} -I$LIBFFI_PREFIX/include -I$Z3_PREFIX/include"
export LDFLAGS="${LDFLAGS:-} -L$LIBFFI_PREFIX/lib -L$Z3_PREFIX/lib"
{
  echo "host=$(hostname)"
  sw_vers
  date -u
  echo "source_commit=$EXPECTED_SOURCE"
  echo "source_tree=$EXPECTED_TREE"
  echo "libffi_prefix=$LIBFFI_PREFIX"
  echo "z3_prefix=$Z3_PREFIX"
  git -C "$SRC" submodule status
  clang++ --version | sed -n '1p'
  make --version | sed -n '1p'
} > "$RUN_DIR/logs/environment.txt"

cd "$SRC"
autoconf
./configure --enable-libveriuser --prefix="$INSTALL" > "$RUN_DIR/logs/configure.log" 2>&1
make -j3 > "$RUN_DIR/logs/build.log" 2>&1
make install > "$RUN_DIR/logs/install.log" 2>&1

UVM_DPI_SRC="$CORPUS/third_party/tests/uvm/src/dpi"
(
  cd "$DPI_MODULE_DIR"
  IVPI="$INSTALL/bin/iverilog-vpi" "$SRC/uvm_dpi/build_uvm_dpi.sh" \
    --name=uvm_dpi -I"$UVM_DPI_SRC" \
    "$SRC/uvm_dpi/uvm_dpi_iverilog.cc"
) > "$RUN_DIR/logs/uvm-dpi-build.log" 2>&1
{
  "$INSTALL/bin/iverilog" -V 2>&1 | sed -n '1,2p'
  "$INSTALL/bin/vvp" -V 2>&1 | sed -n '1,2p'
  shasum -a 256 "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" "$DPI_MODULE_DIR/uvm_dpi.vpi"
} >> "$RUN_DIR/logs/environment.txt"

python3 "$RUN_DIR/run_uvm_subset.py" | tee "$RUN_DIR/logs/summary.log"
echo UVM_DPI_FOLLOWUP_END
