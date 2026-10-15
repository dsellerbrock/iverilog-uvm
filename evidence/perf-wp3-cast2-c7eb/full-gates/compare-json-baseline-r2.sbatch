#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp3-json-base
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-json-baseline-c7eb-20261015-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-json-baseline-c7eb-20261015-r2/logs/%x-%j.out

set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-json-baseline-c7eb-20261015-r2
GATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-gates1
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
SRC=$RUN/source/iverilog-uvm-c7eb
REF_INSTALL=$RUN/reference-install
HELPER=$RUN/incoming/run-json-isolated.py
RESULTS=$RUN/results
LOGS=$RUN/logs

mkdir -p "$RUN/source" "$RUN/incoming" "$RUN/json" "$RESULTS" "$LOGS"
finish() {
  rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

tar -xzf "$RUN/incoming/source.tar.gz" -C "$RUN/source"
sed -nE 's/^[[:space:]]*([[:alnum:]_]+): Failed -.*/\1/p' \
  "$GATE/logs/json-regression.log" | sort -u > "$RUN/incoming/failure-names.txt"
test -s "$RUN/incoming/failure-names.txt"
printf 'measurement_base=%s\n' "$BASE" > "$RUN/source-manifest.txt"
sha256sum "$RUN/incoming/source.tar.gz" "$HELPER" "$RUN/incoming/failure-names.txt" \
  >> "$RUN/source-manifest.txt"

run_timed() {
  name=$1
  limit=$2
  shift 2
  if timeout --signal=TERM --kill-after=15s "$limit" "$@" \
      > "$LOGS/$name.log" 2>&1; then
    printf '%s\t0\n' "$name" >> "$RESULTS/stage-status.tsv"
  else
    rc=$?
    printf '%s\t%s\n' "$name" "$rc" >> "$RESULTS/stage-status.tsv"
    return "$rc"
  fi
}

test "$(wc -l < "$RUN/incoming/failure-names.txt" | tr -d ' ')" -eq 16
run_timed build-reference 5400 bash -c '
  set -euo pipefail
  cd "$1"
  sh autoconf.sh
  ./configure --prefix="$2" --enable-libveriuser CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2"
  make -j4
  make install
' _ "$SRC" "$REF_INSTALL"

python3 "$HELPER" --source "$SRC" --install "$REF_INSTALL" \
  --output "$RUN/json/reference" --names-file "$RUN/incoming/failure-names.txt" \
  --timeout-seconds 300
python3 "$HELPER" --source "$GATE/source" --install "$GATE/build/install" \
  --output "$RUN/json/candidate" --names-file "$RUN/incoming/failure-names.txt" \
  --timeout-seconds 300

cut -f1,4 "$RUN/json/reference/results.tsv" | tail -n +2 | sort \
  > "$RESULTS/reference.tsv"
cut -f1,4 "$RUN/json/candidate/results.tsv" | tail -n +2 | sort \
  > "$RESULTS/candidate.tsv"
if diff -u "$RESULTS/reference.tsv" "$RESULTS/candidate.tsv" \
    > "$RESULTS/candidate-vs-reference.diff"; then
  printf 'same_results_on_all_16_preexisting_failures=yes\n' > "$RESULTS/summary.txt"
else
  printf 'same_results_on_all_16_preexisting_failures=no\n' > "$RESULTS/summary.txt"
  exit 1
fi

