#!/usr/bin/env bash
#SBATCH --job-name=a3-c18c
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
set -euo pipefail

RUN_DIR=$(pwd)
SOURCE="$RUN_DIR/source"
RESULTS="$RUN_DIR/results"
TOOLCHAIN=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install
mkdir -p "$RESULTS"
printf 'HOST=%s\nUNAME=%s\nSOURCE_COMMIT=9b5fad2af\nCC=%s\n' \
	"$(hostname -f)" "$(uname -sm)" "$(gcc --version | head -n 1)" \
	| tee "$RESULTS/manifest.txt"
"$TOOLCHAIN/bin/iverilog" -V > "$RESULTS/iverilog-version.log" 2>&1
"$TOOLCHAIN/bin/vvp" -V > "$RESULTS/vvp-version.log" 2>&1
sha256sum "$TOOLCHAIN/bin/iverilog" "$TOOLCHAIN/bin/vvp" > "$RESULTS/tool-sha256.txt"
export IVERILOG="$TOOLCHAIN/bin/iverilog"
export VVP="$TOOLCHAIN/bin/vvp"
set +e
"$SOURCE/evidence/ieee1800-audit-c18c-20261017/run-probes.sh" "$RESULTS"
rc=$?
set -e
printf 'exit=%s\n' "$rc" > "$RESULTS/script.exit"
exit "$rc"
