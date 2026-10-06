#!/bin/bash
set -euo pipefail

worktree_root=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926
opentitan_root=/private/tmp/ot-corpus-flash-read32-20261006/source
build_root=/private/tmp/pi/iverilog-uvm-flash-read32-20261006
tool_env=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313
uvm_home=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src
rv32_tool_dir=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-verilator-l0-enable-20260923/toolchain/xpack-riscv-none-elf-gcc-12.2.0-3/riscv-none-elf/bin
current_tools="$worktree_root/local-install"
result_dir="$worktree_root/evidence/opentitan-census-20261002/candidate-flash-read32-20261006"

avail_kb=$(df -Pk /private/tmp | awk 'END {print $4}')
if [ "$avail_kb" -lt 4194304 ]; then
  echo "Refusing to start with less than 4 GiB free on /private/tmp: ${avail_kb} KiB"
  exit 2
fi
mkdir -p "$build_root"
cd "$worktree_root"
export PATH="$tool_env/bin:$PATH"
export RV32_TOOL_AS="$rv32_tool_dir/as"
export RV32_TOOL_LD="$rv32_tool_dir/ld"

{
  printf 'OpenTitan source: %s\n' "$opentitan_root"
  printf 'disk available KiB: %s\n' "$avail_kb"
  shasum -a 256 "$current_tools/bin/iverilog" "$current_tools/lib/ivl/ivl" \
    "$current_tools/lib/ivl/vvp.tgt" "$current_tools/bin/vvp"
} > "$result_dir/preflight.log" 2>&1

"$tool_env/bin/python" scripts/opentitan_matrix.py \
  --opentitan-root "$opentitan_root" \
  --build-root "$build_root" \
  --iverilog "$current_tools/bin/iverilog" \
  --uvm-home "$uvm_home" \
  --fusesoc "$tool_env/bin/fusesoc" \
  --fusesoc-python "$tool_env/bin/python" \
  --lane runtime \
  --core lowrisc:dv:flash_ctrl_sim:0.1 \
  --jobs 1 \
  --setup-timeout 600 \
  --compile-timeout 600 \
  --runtime-timeout 18000 \
  --runtime-memory-mib 9536 \
  --commercial-unsafe \
  --native-pkg-config openssl \
  --native-pkg-config libelf \
  --result-json "$result_dir/result.json" \
  --result-md "$result_dir/result.md" \
  2>&1 | tee "$result_dir/runner.log"
