#!/usr/bin/env bash
#SBATCH --job-name=a3-c08q-weak
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00
#SBATCH --output=logs/job-%j.out
set -euo pipefail
RUN_DIR="$(pwd)"
IVL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/vvp
SRC="$RUN_DIR/input/tests/1800_audit/c08"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC"/*.sv > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\trun_rc\tresult\n' > "$OUT/results.tsv"
printf 'W1 1 1\nW2 7\nW4 1\nW5 1 1 1 1\nW5E 1\nW3 1 1\n' > "$OUT/weak_expected.txt"
printf 'FP 1 2 64\n' > "$OUT/fwd_expected.txt"
failures=0

run_positive() {
  local edition="$1" probe="$2" expected="$3" image="$OUT/$2-g$1.vvp"
  if /usr/bin/time -f '%e %M' -o "$OUT/logs/$probe-g$edition.compile.time" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s "$probe" -o "$image" "$SRC/$probe.sv" > "$OUT/logs/$probe-g$edition.compile.log" 2>&1; then
    local crc=0
    if /usr/bin/time -f '%e %M' -o "$OUT/logs/$probe-g$edition.run.time" timeout --kill-after=2s 30s "$VVP" "$image" > "$OUT/logs/$probe-g$edition.run.log" 2>&1; then
      local rrc=0 result=PASS
      if ! diff -u "$expected" "$OUT/logs/$probe-g$edition.run.log"; then result=OUTPUT_MISMATCH; failures=1; fi
    else local rrc=$? result=RUN_FAILED; failures=1; fi
  else local crc=$? rrc=NA result=COMPILE_FAILED; failures=1; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$edition" "$probe" "$crc" "$rrc" "$result" >> "$OUT/results.tsv"
}

run_positive 2023 p08_30_weak "$OUT/weak_expected.txt"
run_positive 2023 p08_30_weak_std "$OUT/weak_expected.txt"
run_positive 2017 p08_27_fwd_param "$OUT/fwd_expected.txt"
run_positive 2023 p08_27_fwd_param "$OUT/fwd_expected.txt"

# §8.30 requires the type parameter to be a class; any non-timeout compile error is expected.
probe=n08_30_weak_int
if /usr/bin/time -f '%e %M' -o "$OUT/logs/$probe-g2023.compile.time" timeout --kill-after=2s 30s "$IVL" -g2023 -s "$probe" -o "$OUT/$probe.vvp" "$SRC/$probe.sv" > "$OUT/logs/$probe-g2023.compile.log" 2>&1; then
  crc=0 result=ACCEPTED; failures=1
else crc=$?; if [ "$crc" -ge 124 ]; then result=TIMEOUT; failures=1; else result=REJECTED; fi; fi
printf '2023\t%s\t%s\tNA\t%s\n' "$probe" "$crc" "$result" >> "$OUT/results.tsv"

# Record 2017 edition behavior; the lead does not require either acceptance or rejection.
probe=p08_30_weak
if /usr/bin/time -f '%e %M' -o "$OUT/logs/$probe-g2017.compile.time" timeout --kill-after=2s 30s "$IVL" -g2017 -s "$probe" -o "$OUT/$probe-g2017.vvp" "$SRC/$probe.sv" > "$OUT/logs/$probe-g2017.compile.log" 2>&1; then
  crc=0 result=ACCEPTED_EXTENSION
else crc=$?; if [ "$crc" -ge 124 ]; then result=TIMEOUT; failures=1; else result=REJECTED; fi; fi
printf '2017\t%s\t%s\tNA\t%s\n' "$probe" "$crc" "$result" >> "$OUT/results.tsv"

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"; cat "$f"
done
exit "$failures"
