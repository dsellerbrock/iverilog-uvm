#!/usr/bin/env bash
#SBATCH --job-name=a3-c35-packed
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=logs/job-%j.out
set -uo pipefail

RUN_DIR="$(pwd)"
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
IVL="$IVL_ROOT/bin/iverilog"
VVP="$IVL_ROOT/bin/vvp"
CC=/usr/bin/gcc
mkdir -p "$RUN_DIR/results/logs" "$RUN_DIR/scratch"
date -u +%FT%TZ > "$RUN_DIR/results/start.utc"
hostname > "$RUN_DIR/results/host.txt"
"$IVL" -V > "$RUN_DIR/results/iverilog-version.txt" 2>&1
"$VVP" -V > "$RUN_DIR/results/vvp-version.txt" 2>&1
"$CC" --version | head -n 1 > "$RUN_DIR/results/gcc-version.txt"
sha256sum "$IVL" "$VVP" "$CC" "$RUN_DIR/input"/* > "$RUN_DIR/results/SHA256SUMS"
printf 'edition\ttest\tcompile_rc\tlink_rc\trun_rc\tpass\n' > "$RUN_DIR/results/results.tsv"
failed=0

for edition in 2017 2023; do
  for name in m10_dpi_wide_vector_test m10_dpi_fixed_packed_array_abi_test; do
    work="$RUN_DIR/scratch/$edition/$name"
    mkdir -p "$work"
    if (cd "$work" && timeout --kill-after=2s 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$edition" -s "$name" -o test.vvp "$RUN_DIR/input/$name.sv") > "$RUN_DIR/results/logs/$edition.$name.compile.log" 2>&1; then crc=0; else crc=$?; failed=1; fi
    if [ "$crc" -eq 0 ]; then
      if (cd "$work" && timeout --kill-after=2s 30s "$CC" -shared -fPIC -I "$IVL_ROOT/include/iverilog" -o libdpi.so "$RUN_DIR/input/$name.c") > "$RUN_DIR/results/logs/$edition.$name.link.log" 2>&1; then lrc=0; else lrc=$?; failed=1; fi
    else lrc=NA; fi
    if [ "$crc" -eq 0 ] && [ "$lrc" -eq 0 ]; then
      if (cd "$work" && timeout --kill-after=2s 30s "$VVP" -d ./libdpi.so ./test.vvp) > "$RUN_DIR/results/logs/$edition.$name.stdout.log" 2> "$RUN_DIR/results/logs/$edition.$name.stderr.log"; then rrc=0; else rrc=$?; failed=1; fi
    else rrc=NA; fi
    case "$name" in
      m10_dpi_wide_vector_test) marker='^PASS: m10 dpi wide vector$' ;;
      m10_dpi_fixed_packed_array_abi_test) marker='^PASS m10_dpi_fixed_packed_array_abi_test$' ;;
    esac
    if [ "$rrc" = 0 ] && grep -Eq "$marker" "$RUN_DIR/results/logs/$edition.$name.stdout.log" && ! grep -Eq '^(FAIL|FAILED)(:| )' "$RUN_DIR/results/logs/$edition.$name.stdout.log"; then pass=YES; else pass=NO; failed=1; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$edition" "$name" "$crc" "$lrc" "$rrc" "$pass" >> "$RUN_DIR/results/results.tsv"
  done
done

date -u +%FT%TZ > "$RUN_DIR/results/end.utc"
cat "$RUN_DIR/results/results.tsv"
for f in "$RUN_DIR/results"/logs/*.stdout.log "$RUN_DIR/results"/logs/*.stderr.log; do [ -f "$f" ] || continue; echo "--- ${f##*/}"; cat "$f"; done
exit "$failed"
