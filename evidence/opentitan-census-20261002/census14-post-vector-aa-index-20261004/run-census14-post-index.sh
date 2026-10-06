#!/bin/bash
set -euo pipefail

worktree_root=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926
opentitan_root=/private/tmp/ot-corpus-current-spid-passthrough-20261003/source
build_root=/private/tmp/pi/census14/build
tool_env=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313
uvm_home=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src
rv32_tool_dir=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-verilator-l0-enable-20260923/toolchain/xpack-riscv-none-elf-gcc-12.2.0-3/riscv-none-elf/bin
result_dir="$worktree_root/evidence/opentitan-census-20261002/census14-post-vector-aa-index-20261004"
current_tools="$worktree_root/local-install"

mkdir -p "$result_dir" "$build_root"
exec >"$result_dir/runner.log" 2>&1
cd "$worktree_root"

preflight_log="$result_dir/preflight.log"
{
  printf 'branch: %s\n' "$(git branch --show-current)"
  printf 'head: %s\n' "$(git rev-parse HEAD)"
  printf 'OpenTitan source: %s\n' "$opentitan_root"
  printf 'compiler/runtime fingerprints:\n'
  shasum -a 256 \
    "$current_tools/bin/iverilog" \
    "$current_tools/lib/ivl/ivl" \
    "$current_tools/lib/ivl/vvp.tgt" \
    "$current_tools/bin/vvp"
  "$current_tools/bin/iverilog" -V
  printf 'focused compatibility patches are present (reverse dry-run):\n'
  for patch_file in \
    "$result_dir/../census12-full-corpus-20261003/compat-patches/otp-get-offset-covergroup-purity.patch" \
    "$result_dir/../census12-full-corpus-20261003/compat-patches/flash-elementwise-solve-before.patch" \
    "$result_dir/../census12-full-corpus-20261003/compat-patches/spi-tpm-sram-csb-reset.patch"; do
    patch --dry-run -R -p1 -d "$opentitan_root" < "$patch_file"
  done
} >"$preflight_log" 2>&1

export RV32_TOOL_AS="$rv32_tool_dir/as"
export RV32_TOOL_LD="$rv32_tool_dir/ld"

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
  --result-json "$result_dir/result-census14.json" \
  --result-md "$result_dir/result-census14.md"
