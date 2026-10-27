#!/usr/bin/env bash
#SBATCH --job-name=a3-c08o-const-r2
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
sha256sum "$IVL" "$VVP" "$SRC/p08_19_20.sv" "$SRC/r08_19_const_double_assignment.sv" \
  "$SRC/neg/n08_19_const_global_reassign.sv" \
  "$SRC/neg/n08_19_const_instance_outside_ctor.sv" \
  "$SRC/neg/n08_19_const_static_instance.sv" \
  "$SRC/neg/n08_19_const_external_write.sv" \
  "$SRC/neg/n08_20_override_arg_name.sv" \
  "$SRC/neg/n08_20_override_arg_type.sv" \
  "$SRC/neg/n08_20_override_direction.sv" \
  "$SRC/neg/n08_20_override_return_type.sv" \
  "$SRC/neg/n08_20_override_default_presence.sv" > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\trun_rc\tcompile_sec\tcompile_kib\trun_sec\trun_kib\tresult\n' > "$OUT/results.tsv"
printf 'K1 9216 5\nK2 3 4\nV6 ok\nV7 2\n' > "$OUT/expected.txt"
failures=0

for edition in 2017 2023; do
  probe=p08_19_20; image="$OUT/$probe-g$edition.vvp"
  cl="$OUT/logs/$probe-g$edition.compile.log"; rl="$OUT/logs/$probe-g$edition.run.log"
  ct="$OUT/logs/$probe-g$edition.compile.time"; rt="$OUT/logs/$probe-g$edition.run.time"
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

  for probe in n08_19_const_global_reassign n08_19_const_instance_outside_ctor \
      n08_19_const_static_instance n08_19_const_external_write \
      n08_20_override_arg_name n08_20_override_arg_type n08_20_override_direction \
      n08_20_override_return_type n08_20_override_default_presence; do
    src="$SRC/neg/$probe.sv"; image="$OUT/$probe-g$edition.vvp"
    cl="$OUT/logs/$probe-g$edition.compile.log"; ct="$OUT/logs/$probe-g$edition.compile.time"
    if /usr/bin/time -f '%e %M' -o "$ct" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s "$probe" -o "$image" "$src" > "$cl" 2>&1; then
      crc=0; result=FAIL_ACCEPTED; failures=1
    else
      crc=$?
      if [ "$crc" -ge 124 ]; then result=FAIL_TIMEOUT; failures=1; else result=REJECTED; fi
    fi
    read -r csec cmem < <(tail -n 1 "$ct")
    printf '%s\t%s\t%s\tNA\t%s\t%s\tNA\tNA\t%s\n' "$edition" "$probe" "$crc" "$csec" "$cmem" "$result" >> "$OUT/results.tsv"
  done

  probe=r08_19_const_double_assignment; image="$OUT/$probe-g$edition.vvp"
  cl="$OUT/logs/$probe-g$edition.compile.log"; ct="$OUT/logs/$probe-g$edition.compile.time"
  rrc=NA; rsec=NA; rmem=NA
  if /usr/bin/time -f '%e %M' -o "$ct" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s "$probe" -o "$image" "$SRC/$probe.sv" > "$cl" 2>&1; then
    crc=0; result=COMPILED
    rl="$OUT/logs/$probe-g$edition.run.log"; rt="$OUT/logs/$probe-g$edition.run.time"
    if /usr/bin/time -f '%e %M' -o "$rt" timeout --kill-after=2s 30s "$VVP" "$image" > "$rl" 2>&1; then
      rrc=0; read -r rsec rmem < <(tail -n 1 "$rt"); result=COMPILED_AND_RAN
    else rrc=$?; read -r rsec rmem < <(tail -n 1 "$rt"); result=RUN_FAILED; fi
  else
    crc=$?; rrc=NA; rsec=NA; rmem=NA; result=REJECTED_RECORD_ONLY
  fi
  read -r csec cmem < <(tail -n 1 "$ct")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$edition" "$probe" "$crc" "$rrc" "$csec" "$cmem" "${rsec:-NA}" "${rmem:-NA}" "$result" >> "$OUT/results.tsv"
done

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"; cat "$f"
done
exit "$failures"
