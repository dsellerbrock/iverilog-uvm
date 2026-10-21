#!/usr/bin/env bash
#SBATCH --job-name=a3-c07-map
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-map-20261020-01/logs/%x-%j.out

set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-map-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Tool: '; "$TOOL/iverilog" -V | head -n 1
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$SRC"/*.sv

for edition in 2017 2023; do
  binary="$OUT/p07_12_4_iterarg-${edition}.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" "-g$edition" -s p07_12_4_iterarg -o "$binary" "$SRC/p07_12_4_iterarg.sv" >"$OUT/iterarg-${edition}.compile.out" 2>"$OUT/iterarg-${edition}.compile.err"; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf 'iterarg-%s compile_rc=%s\n' "$edition" "$compile_rc"
  if [ "$compile_rc" -eq 0 ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/iterarg-${edition}.run.out" 2>"$OUT/iterarg-${edition}.run.err"; then
      run_rc=0
    else
      run_rc=$?
    fi
    printf 'iterarg-%s run_rc=%s\n' "$edition" "$run_rc"
    cat "$OUT/iterarg-${edition}.run.out" "$OUT/iterarg-${edition}.run.err"
  fi
done

binary="$OUT/p07_12_5_map-2023.vvp"
if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" -g2023 -s p07_12_5_map -o "$binary" "$SRC/p07_12_5_map.sv" >"$OUT/map-2023.compile.out" 2>"$OUT/map-2023.compile.err"; then
  compile_rc=0
else
  compile_rc=$?
fi
printf 'map-2023 compile_rc=%s\n' "$compile_rc"
if [ "$compile_rc" -eq 0 ]; then
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/map-2023.run.out" 2>"$OUT/map-2023.run.err"; then
    run_rc=0
  else
    run_rc=$?
  fi
  printf 'map-2023 run_rc=%s\n' "$run_rc"
  cat "$OUT/map-2023.run.out" "$OUT/map-2023.run.err"
fi

binary="$OUT/p07_12_5_map-2017.vvp"
if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" -g2017 -s p07_12_5_map -o "$binary" "$SRC/p07_12_5_map.sv" >"$OUT/map-2017.compile.out" 2>"$OUT/map-2017.compile.err"; then
  compile_rc=0
else
  compile_rc=$?
fi
printf 'map-2017 compile_rc=%s (expected nonzero)\n' "$compile_rc"
cat "$OUT/map-2017.compile.out" "$OUT/map-2017.compile.err"
