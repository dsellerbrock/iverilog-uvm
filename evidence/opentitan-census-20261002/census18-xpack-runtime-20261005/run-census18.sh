#!/bin/bash
set -euo pipefail

worktree_root=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926
opentitan_root=/private/tmp/ot-corpus-current-spid-passthrough-20261003/source
build_root=/private/tmp/pi/opentitan-runtime-census18-xpack-20261005/build
tool_env=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313
uvm_home=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src
rv32_tool_dir=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-verilator-l0-enable-20260923/toolchain/xpack-riscv-none-elf-gcc-12.2.0-3/riscv-none-elf/bin
result_dir="$worktree_root/evidence/opentitan-census-20261002/census18-xpack-runtime-20261005"
current_tools="$worktree_root/local-install"

mkdir -p "$result_dir" "$build_root"
exec >"$result_dir/runner.log" 2>&1
cd "$worktree_root"

export PATH="$tool_env/bin:$PATH"
export RV32_TOOL_AS="$rv32_tool_dir/as"
export RV32_TOOL_LD="$rv32_tool_dir/ld"

printf 'branch: %s\n' "$(git branch --show-current)"
printf 'head: %s\n' "$(git rev-parse HEAD)"
printf 'OpenTitan source: %s\n' "$opentitan_root"
shasum -a 256 "$RV32_TOOL_AS" "$RV32_TOOL_LD"

"$tool_env/bin/python" scripts/opentitan_matrix.py \
  --opentitan-root "$opentitan_root" \
  --build-root "$build_root" \
  --iverilog "$current_tools/bin/iverilog" \
  --uvm-home "$uvm_home" \
  --fusesoc "$tool_env/bin/fusesoc" \
  --fusesoc-python "$tool_env/bin/python" \
  --lane runtime \
  --jobs 2 \
  --setup-timeout 600 \
  --compile-timeout 600 \
  --runtime-timeout 18000 \
  --runtime-memory-mib 9536 \
  --commercial-unsafe \
  --native-pkg-config openssl \
  --native-pkg-config libelf \
  --result-json "$result_dir/result.json" \
  --result-md "$result_dir/result.md"
