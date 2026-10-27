#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c17-procedural
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=logs/job-%j.out
set -uo pipefail
RUN_DIR="$(pwd)"
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
IVL="$IVL_ROOT/bin/iverilog"
VVP="$IVL_ROOT/bin/vvp"
mkdir -p "$RUN_DIR/results/logs" "$RUN_DIR/scratch"
date -u +%FT%TZ > "$RUN_DIR/results/start.utc"
hostname > "$RUN_DIR/results/host.txt"
uptime >> "$RUN_DIR/results/host.txt"
"$IVL" -V > "$RUN_DIR/results/iverilog-version.txt" 2>&1
"$VVP" -V > "$RUN_DIR/results/vvp-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$RUN_DIR/input/p17_03_procedural_checker_instance.sv" > "$RUN_DIR/results/SHA256SUMS"
printf 'edition\tcase\tcompile_rc\trun_rc\tresult\n' > "$RUN_DIR/results/results.tsv"
for edition in 2017 2023; do
  for case_name in procedural static_control; do
    work="$RUN_DIR/scratch/$edition-$case_name"
    mkdir -p "$work"
    if [ "$case_name" = procedural ]; then
      source="$RUN_DIR/input/p17_03_procedural_checker_instance.sv"
      top=p17_03_procedural_checker_instance
    else
      source="$RUN_DIR/input/sv_checker_basic.v"
      top=main
    fi
    if (cd "$work" && /usr/bin/time -f '%e %M' -o "$RUN_DIR/results/logs/$edition-$case_name.compile.time" timeout --kill-after=2s 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$edition" -s "$top" -o test.vvp "$source") > "$RUN_DIR/results/logs/$edition-$case_name.compile.log" 2>&1; then crc=0; else crc=$?; fi
    rrc=NA
    result=COMPILE_REJECTED
    if [ "$crc" -eq 0 ]; then
      if (cd "$work" && /usr/bin/time -f '%e %M' -o "$RUN_DIR/results/logs/$edition-$case_name.run.time" timeout --kill-after=2s 30s "$VVP" test.vvp) > "$RUN_DIR/results/logs/$edition-$case_name.stdout.log" 2> "$RUN_DIR/results/logs/$edition-$case_name.stderr.log"; then rrc=0; else rrc=$?; fi
      if [ "$rrc" -eq 0 ] && grep -Eq 'PASS procedural checker instance|PASSED' "$RUN_DIR/results/logs/$edition-$case_name.stdout.log"; then result=PASS; else result=RUN_FAIL; fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$edition" "$case_name" "$crc" "$rrc" "$result" >> "$RUN_DIR/results/results.tsv"
  done
done
date -u +%FT%TZ > "$RUN_DIR/results/end.utc"
cat "$RUN_DIR/results/results.tsv"
for f in "$RUN_DIR/results"/logs/*.compile.log "$RUN_DIR/results"/logs/*.stdout.log "$RUN_DIR/results"/logs/*.stderr.log; do [ -f "$f" ] || continue; echo "--- ${f##*/}"; cat "$f"; done
