#!/usr/bin/env bash
#SBATCH --job-name=a3-c18q-guards
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --output=logs/job-%j.out
set -euo pipefail

RUN_DIR="$(pwd)"
IVL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/vvp
TIMEOUT="$RUN_DIR/input/run_with_timeout.py"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$RUN_DIR/input"/*.sv "$TIMEOUT" > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\trun_rc\tcompile_sec\tcompile_kib\trun_sec\trun_kib\n' > "$OUT/results.tsv"

for edition in 2017 2023; do
  probe=p18_05_13_guards
  src="$RUN_DIR/input/$probe.sv"
  image="$OUT/$probe-g$edition.vvp"
  compile_log="$OUT/logs/$probe-g$edition.compile.log"
  run_log="$OUT/logs/$probe-g$edition.run.log"
  compile_time="$OUT/logs/$probe-g$edition.compile.time"
  run_time="$OUT/logs/$probe-g$edition.run.time"
  if /usr/bin/time -f '%e %M' -o "$compile_time" python3 "$TIMEOUT" 30 -- \
      "$IVL" -g"$edition" -s "$probe" -o "$image" "$src" > "$compile_log" 2>&1; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  run_rc=NA
  run_sec=NA
  run_kib=NA
  if [ "$compile_rc" -eq 0 ]; then
    if /usr/bin/time -f '%e %M' -o "$run_time" python3 "$TIMEOUT" 30 -- \
        "$VVP" "$image" > "$run_log" 2>&1; then
      run_rc=0
    else
      run_rc=$?
    fi
    read -r run_sec run_kib < <(tail -n 1 "$run_time")
  fi
  read -r compile_sec compile_kib < <(tail -n 1 "$compile_time")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$edition" "$probe" "$compile_rc" "$run_rc" "$compile_sec" \
      "$compile_kib" "$run_sec" "$run_kib" >> "$OUT/results.tsv"
done

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"
  cat "$f"
done
