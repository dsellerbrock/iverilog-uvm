#!/bin/sh
set -eu

worktree_root=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926
opentitan_root=/private/tmp/ot-corpus-after-fixes-20260929/source
build_root=/private/tmp/pi/census12/build
tool_env=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313
uvm_home=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src
result_dir="$worktree_root/evidence/opentitan-census-20261002/census12-full-corpus-20261003"

cd "$worktree_root"
"$tool_env/bin/python" scripts/opentitan_matrix.py \
  --opentitan-root "$opentitan_root" \
  --build-root "$build_root" \
  --iverilog /private/tmp/current-tools/bin/iverilog \
  --uvm-home "$uvm_home" \
  --fusesoc "$tool_env/bin/fusesoc" \
  --fusesoc-python "$tool_env/bin/python" \
  --lane runtime \
  --jobs 2 \
  --setup-timeout 600 \
  --compile-timeout 600 \
  --runtime-timeout 3000 \
  --runtime-memory-mib 0 \
  --commercial-unsafe \
  --native-pkg-config openssl \
  --native-pkg-config libelf \
  --result-json "$result_dir/result-census12.json" \
  --result-md "$result_dir/result-census12.md"
