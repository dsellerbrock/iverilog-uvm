#!/usr/bin/env bash
# Reproduce the MSYS2 libsystre/TRE uvm_re_comp crash on Linux.
# Needs libtre-dev. Usage (from the repository root):
#   bash evidence/win-regex-tre/run.sh [umbrella.cc]
# Default umbrella is uvm_dpi/uvm_dpi_iverilog.cc; pass a pre-fix copy to see red.
set -eu
D="$(cd "$(dirname "$0")" && pwd)"
U="${1:-uvm_dpi/uvm_dpi_iverilog.cc}"
T="$(mktemp -d)"
gcc -g -c "$D/systre.c" -o "$T/systre.o"
g++ -g -fsanitize=address -w -I"$D" -I. -Iuvm_dpi -Ivpi -Iuvm-core/src/dpi \
    -c "$U" -o "$T/umbrella.o"
gcc -g -fsanitize=address "$D/harness.c" "$T/umbrella.o" "$T/systre.o" -ltre \
    -lstdc++ -Wl,--unresolved-symbols=ignore-all -o "$T/harness"
ASAN_OPTIONS=detect_leaks=0 "$T/harness"
