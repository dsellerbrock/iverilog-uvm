#!/usr/bin/env bash
#SBATCH --job-name=a3-c08m-virtual
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
SRC="$RUN_DIR/input/tests/1800_audit/c08"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC/p08_20_22.sv" "$SRC/neg/n08_21_construct_abstract.sv" "$SRC/neg/n08_21_pure_in_concrete.sv" "$SRC/neg/n08_21_missing_implementation.sv" "$SRC/neg/n08_21_pure_with_body.sv" > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\trun_rc\tcompile_sec\tcompile_kib\trun_sec\trun_kib\tresult\n' > "$OUT/results.tsv"
printf 'V1 C C\nV2 A2 C2\nAB1 5\nAB2 x\nPOLY Ether Token GPS\n' > "$OUT/expected.txt"
failures=0
for edition in 2017 2023; do
  probe=p08_20_22
  image="$OUT/$probe-g$edition.vvp"
  cl="$OUT/logs/$probe-g$edition.compile.log"
  rl="$OUT/logs/$probe-g$edition.run.log"
  ct="$OUT/logs/$probe-g$edition.compile.time"
  rt="$OUT/logs/$probe-g$edition.run.time"
  if /usr/bin/time -f '%e %M' -o "$ct" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s "$probe" -o "$image" "$SRC/$probe.sv" > "$cl" 2>&1; then crc=0; else crc=$?; failures=1; fi
  rrc=NA; rsec=NA; rmem=NA; result=FAIL
  if [ "$crc" -eq 0 ]; then
    if /usr/bin/time -f '%e %M' -o "$rt" timeout --kill-after=2s 30s "$VVP" "$image" > "$rl" 2>&1; then
      rrc=0; read -r rsec rmem < <(tail -n 1 "$rt")
      if diff -u "$OUT/expected.txt" "$rl"; then result=PASS; else failures=1; fi
    else rrc=$?; failures=1; fi
  fi
  read -r csec cmem < <(tail -n 1 "$ct")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$edition" "$probe" "$crc" "$rrc" "$csec" "$cmem" "$rsec" "$rmem" "$result" >> "$OUT/results.tsv"
  for probe in n08_21_construct_abstract n08_21_pure_in_concrete n08_21_missing_implementation n08_21_pure_with_body; do
    src="$SRC/neg/$probe.sv"; cl="$OUT/logs/$probe-g$edition.compile.log"; ct="$OUT/logs/$probe-g$edition.compile.time"
    if /usr/bin/time -f '%e %M' -o "$ct" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s "$probe" -o "$OUT/$probe-g$edition.vvp" "$src" > "$cl" 2>&1; then
      crc=0; result=FAIL_ACCEPTED; failures=1
    else
      crc=$?
      if [ "$crc" -ge 124 ]; then result=FAIL_TIMEOUT; failures=1; else result=REJECTED; fi
    fi
    read -r csec cmem < <(tail -n 1 "$ct")
    printf '%s\t%s\t%s\tNA\t%s\t%s\tNA\tNA\t%s\n' "$edition" "$probe" "$crc" "$csec" "$cmem" "$result" >> "$OUT/results.tsv"
  done
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"; cat "$f"
done
exit "$failures"
