#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-1800-c18-c19-r2
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01/logs/%x-%j.out
set -Eeuo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue680-build-20261019-01
SRC="$RUN/source"
IVL="$SRC/local-install/bin/iverilog"
VVP="$SRC/local-install/bin/vvp"
OUT="$RUN/audit-results-r2"
mkdir -p "$OUT"
export PATH="$SRC/local-install/bin:$PATH"
export IVERILOG="$IVL"
export VVP
export IVPI="$SRC/local-install/bin/iverilog-vpi"
exec > >(tee "$OUT/combined.log") 2>&1

echo "host=$(hostname)"
echo "base=82023726be90ab269d6e0ef5e755ebb69e6f648c"
"$IVL" -V > "$OUT/iverilog-version.log" 2>&1
head -n 1 "$OUT/iverilog-version.log"
sha256sum "$IVL" "$VVP"

status=0
P18="$SRC/tests/1800_audit/c18/p18_12_scope_randomize.sv"
for edition in 2017 2023; do
  if timeout --signal=TERM --kill-after=5s 60s \
    "$IVL" -g"$edition" -s test -o "$OUT/p18_12_$edition.vvp" "$P18" \
    > "$OUT/p18_12_$edition.compile.log" 2>&1; then
    timeout --signal=TERM --kill-after=5s 60s "$VVP" -n \
      "$OUT/p18_12_$edition.vvp" \
      > "$OUT/p18_12_$edition.run.log" 2>&1 || status=1
    grep -qx 'PASS scope randomize clause 18.12' \
      "$OUT/p18_12_$edition.run.log" || status=1
  else
    status=1
  fi
done

for probe in n18_12_scope_randomize_no_args n18_12_scope_randomize_expr; do
  for edition in 2017 2023; do
    src="$SRC/tests/1800_audit/c18/neg/$probe.sv"
    if timeout --signal=TERM --kill-after=5s 60s \
      "$IVL" -g"$edition" -s test -o "$OUT/$probe-$edition.vvp" "$src" \
      > "$OUT/$probe-$edition.log" 2>&1; then
      echo "$probe -g$edition: COMPILED"
      if timeout --signal=TERM --kill-after=5s 60s "$VVP" -n "$OUT/$probe-$edition.vvp" \
        > "$OUT/$probe-$edition.run.log" 2>&1; then
        echo "$probe -g$edition runtime: EXIT 0"
      else
        echo "$probe -g$edition runtime: NONZERO"
      fi
    else
      echo "$probe -g$edition: REJECTED"
    fi
  done
done

cd "$SRC/ivtest"
grep '^sv_covergroup_class_inheritance' regress-vvp.list \
  > "$OUT/c19-inheritance.list"
while IFS=$'\t' read -r name descriptor; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  printf '%s\t%s\n' "$name" "$descriptor" > "$OUT/one-c19.list"
  if ! timeout --signal=TERM --kill-after=5s 120s \
    python3 ./vvp_reg.py "$OUT/one-c19.list" \
    > "$OUT/c19-$name.log" 2>&1; then
    status=1
  fi
done < "$OUT/c19-inheritance.list"
if grep -H 'Test results: Ran .*Failed [1-9]' "$OUT"/c19-*.log; then
  status=1
fi
if [[ $status -eq 0 ]]; then echo 'AUDIT RESULT: PASS'; else echo 'AUDIT RESULT: FAIL'; fi
exit "$status"
