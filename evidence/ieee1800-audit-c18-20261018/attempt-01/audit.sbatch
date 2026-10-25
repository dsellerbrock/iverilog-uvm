#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-8
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/audit-c18-08-20261018/logs/a3-c18-8-%j.out
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

for standard in 2017 2023; do
  image="$RESULT/work/modes-$standard.vvp"
  if ! timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$standard" -s test \
      -o "$image" "$RUN/input/p18_08_modes.sv" \
      > "$RESULT/modes-$standard.compile.log" 2>&1; then
    echo "modes-$standard=COMPILE_FAIL" | tee -a "$RESULT/RESULT.txt"
    exit 1
  fi
  if ! timeout --signal=TERM --kill-after=5s 60s "$VVP" -n "$image" \
      > "$RESULT/modes-$standard.run.log" 2>&1; then
    echo "modes-$standard=RUN_FAIL" | tee -a "$RESULT/RESULT.txt"
    exit 1
  fi
  grep -Fq 'PASS rand_mode clause 18.8' "$RESULT/modes-$standard.run.log"
  echo "modes-$standard=PASS" | tee -a "$RESULT/RESULT.txt"
done

for standard in 2017 2023; do
  if timeout --signal=TERM --kill-after=5s 60s "$IVL" -g"$standard" -s test \
      -o "$RESULT/work/override-$standard.vvp" \
      "$RUN/input/n18_08_rand_mode_override.sv" \
      > "$RESULT/override-$standard.compile.log" 2>&1; then
    echo "override-$standard=ACCEPTED (expected compile rejection)" | tee -a "$RESULT/RESULT.txt"
    exit 1
  else
    rc=$?
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
      echo "override-$standard=TIMEOUT" | tee -a "$RESULT/RESULT.txt"
      exit 1
    fi
    echo "override-$standard=REJECTED rc=$rc; diagnostic requires review" | tee -a "$RESULT/RESULT.txt"
  fi
done

echo "finished=$(date -Is)" >> "$RESULT/RESULT.txt"
