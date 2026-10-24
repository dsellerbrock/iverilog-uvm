#!/usr/bin/env bash
#SBATCH --job-name=a3-c08l-iface-sub
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
SRC="$RUN_DIR/input"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC"/*.sv "$TIMEOUT" > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\trun_rc\tcompile_sec\tcompile_kib\trun_sec\trun_kib\n' > "$OUT/positive.tsv"
printf 'edition\tprobe\tcompile_rc\texpected\tcompile_sec\tcompile_kib\n' > "$OUT/negative.tsv"
failures=0

for edition in 2017 2023; do
  probe=p08_26_sub
  src="$SRC/$probe.sv"
  image="$OUT/$probe-g$edition.vvp"
  cl="$OUT/logs/$probe-g$edition.compile.log"
  rl="$OUT/logs/$probe-g$edition.run.log"
  ct="$OUT/logs/$probe-g$edition.compile.time"
  rt="$OUT/logs/$probe-g$edition.run.time"
  if /usr/bin/time -f '%e %M' -o "$ct" python3 "$TIMEOUT" 30 -- \
      "$IVL" -g"$edition" -s "$probe" -o "$image" "$src" > "$cl" 2>&1; then
    crc=0
  else
    crc=$?
    failures=1
  fi
  rrc=NA; rsec=NA; rmem=NA
  if [ "$crc" -eq 0 ]; then
    if /usr/bin/time -f '%e %M' -o "$rt" python3 "$TIMEOUT" 30 -- \
        "$VVP" "$image" > "$rl" 2>&1; then
      rrc=0
    else
      rrc=$?
      failures=1
    fi
    read -r rsec rmem < <(tail -n 1 "$rt")
  fi
  read -r csec cmem < <(tail -n 1 "$ct")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$edition" "$probe" "$crc" "$rrc" "$csec" "$cmem" "$rsec" "$rmem" >> "$OUT/positive.tsv"

  for probe in n08_26_sub_m1_type_not_inherited \
      n08_26_sub_m2_implements_type_parameter \
      n08_26_sub_m3_forward_interface_typedef \
      n08_26_sub_m4_new_interface_handle \
      n08_26_sub_m5_inherited_nonvirtual \
      n08_26_sub_m6_nested_interface_class; do
    src="$SRC/$probe.sv"
    cl="$OUT/logs/$probe-g$edition.compile.log"
    ct="$OUT/logs/$probe-g$edition.compile.time"
    if /usr/bin/time -f '%e %M' -o "$ct" python3 "$TIMEOUT" 30 -- \
        "$IVL" -g"$edition" -s "$probe" -o "$OUT/$probe-g$edition.vvp" "$src" > "$cl" 2>&1; then
      crc=0
      failures=1
    else
      crc=$?
      [ "$crc" -ne 124 ] || failures=1
    fi
    read -r csec cmem < <(tail -n 1 "$ct")
    printf '%s\t%s\t%s\texpected-nonzero\t%s\t%s\n' \
      "$edition" "$probe" "$crc" "$csec" "$cmem" >> "$OUT/negative.tsv"
  done
done

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/positive.tsv" "$OUT/negative.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"
  cat "$f"
done
exit "$failures"
