#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-8-r1
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/audit-c18-08-20261018/logs/a3-c18-8-r1-%j.out
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/audit-c18-08-20261018
CAND=/home/dsell/slurm-runs/iverilog-uvm/a3/t2-batch5-20261018-retry1/source/local-install
RESULT="$RUN/results/$SLURM_JOB_ID"
mkdir -p "$RESULT" "$RESULT/work"
IVL="$CAND/bin/iverilog"
VVP="$CAND/bin/vvp"
export PATH="$CAND/bin:$PATH"
printf 'candidate_commit=4bfe7d04ca190adc9ad74268445bf42a6f187f59\nhost=%s\nstarted=%s\ncpus=1\nmem=2G\n' "$(hostname)" "$(date -Is)" > "$RESULT/RESULT.txt"
sha256sum "$IVL" "$VVP" > "$RESULT/tool-binaries.sha256"
sha256sum "$RUN/input/"*.sv > "$RESULT/probe-inputs.sha256"

failures=0
run_positive() {
  local name=$1 standard=$2 file=$3 marker=$4 image="$RESULT/work/$1-$2.vvp"
  if ! timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$standard" -s test \
      -o "$image" "$RUN/input/$file" > "$RESULT/$name-$standard.compile.log" 2>&1; then
    echo "$name-$standard=COMPILE_FAIL" | tee -a "$RESULT/RESULT.txt"
    failures=1
    return
  fi
  if ! timeout --signal=TERM --kill-after=5s 60s "$VVP" -n "$image" \
      > "$RESULT/$name-$standard.run.log" 2>&1; then
    echo "$name-$standard=RUN_FAIL" | tee -a "$RESULT/RESULT.txt"
    failures=1
    return
  fi
  if ! grep -Fq "$marker" "$RESULT/$name-$standard.run.log"; then
    echo "$name-$standard=MARKER_MISSING" | tee -a "$RESULT/RESULT.txt"
    failures=1
    return
  fi
  echo "$name-$standard=PASS" | tee -a "$RESULT/RESULT.txt"
}

for standard in 2017 2023; do
  run_positive modes "$standard" p18_08_modes.sv 'PASS rand_mode clause 18.8'
  run_positive struct "$standard" p18_08_struct_mode.sv 'PASS rand_mode unpacked-struct selection'
done

for standard in 2017 2023; do
  if timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$standard" -s test \
      -o "$RESULT/work/override-$standard.vvp" \
      "$RUN/input/n18_08_rand_mode_override.sv" \
      > "$RESULT/override-$standard.compile.log" 2>&1; then
    echo "override-$standard=ACCEPTED (expected compile rejection)" | tee -a "$RESULT/RESULT.txt"
    failures=1
  else
    rc=$?
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
      echo "override-$standard=TIMEOUT" | tee -a "$RESULT/RESULT.txt"
      failures=1
    else
      echo "override-$standard=REJECTED rc=$rc; diagnostic requires review" | tee -a "$RESULT/RESULT.txt"
    fi
  fi
done

echo "finished=$(date -Is)" >> "$RESULT/RESULT.txt"
exit "$failures"
