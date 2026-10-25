#!/usr/bin/env bash
#SBATCH --job-name=a3-c08p-method-spec
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
printf 'B.f1\nA.f2\nConcreteB.f3\nA.f4\nConcreteC.f3\nC.f5\n' > "$OUT/expected.txt"
failures=0

# Legal example and runtime check in 2023 mode.
probe=p08_20_spec_legal
image="$OUT/$probe-g2023.vvp"
if timeout --kill-after=2s 30s "$IVL" -g2023 -s "$probe" -o "$image" "$SRC/$probe.sv" > "$OUT/logs/$probe-g2023.compile.log" 2>&1; then
  crc=0
  if timeout --kill-after=2s 30s "$VVP" "$image" > "$OUT/logs/$probe-g2023.run.log" 2>&1; then
    rrc=0
    if diff -u "$OUT/expected.txt" "$OUT/logs/$probe-g2023.run.log"; then result=PASS; else result=OUTPUT_MISMATCH; failures=1; fi
  else rrc=$?; result=RUN_FAILED; failures=1; fi
else crc=$?; rrc=NA; result=COMPILE_FAILED; failures=1; fi
printf '2023\t%s\t%s\t%s\t%s\n' "$probe" "$crc" "$rrc" "$result" >> "$OUT/results.tsv"

# The standard's five illegal declarations plus three boundary negatives.
for probe in p08_20_spec_n1 p08_20_spec_n2 p08_20_spec_n3 p08_20_spec_n4 p08_20_spec_n5 p08_20_spec_e1 p08_20_spec_e2 p08_20_spec_e3; do
  if timeout --kill-after=2s 30s "$IVL" -g2023 -s "$probe" -o "$OUT/$probe.vvp" "$SRC/$probe.sv" > "$OUT/logs/$probe-g2023.compile.log" 2>&1; then
    crc=0; result=ACCEPTED; failures=1
  else crc=$?; if [ "$crc" -ge 124 ]; then result=TIMEOUT; failures=1; else result=REJECTED; fi; fi
  printf '2023\t%s\t%s\tNA\t%s\n' "$probe" "$crc" "$result" >> "$OUT/results.tsv"
done

# Edition gate: 2023 method specifiers must be rejected in 2017 mode.
probe=p08_20_spec_legal
if timeout --kill-after=2s 30s "$IVL" -g2017 -s "$probe" -o "$OUT/$probe-g2017.vvp" "$SRC/$probe.sv" > "$OUT/logs/$probe-g2017.compile.log" 2>&1; then
  crc=0; result=ACCEPTED; failures=1
else crc=$?; if [ "$crc" -ge 124 ]; then result=TIMEOUT; failures=1; else result=REJECTED; fi; fi
printf '2017\t%s\t%s\tNA\t%s\n' "$probe" "$crc" "$result" >> "$OUT/results.tsv"

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"; cat "$f"
done
exit "$failures"
