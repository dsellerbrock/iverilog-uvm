#!/usr/bin/env bash
set -euo pipefail

if (( $# != 7 )); then
  echo "usage: callgrind-instruction-ab.sh <reference-vvp> <candidate-vvp> <iverilog> <valgrind> <valgrind-lib> <source.sv> <output-dir>" >&2
  exit 2
fi

REF_VVP=$1
CANDIDATE_VVP=$2
IVERILOG=$3
VALGRIND=$4
VALGRIND_LIB=$5
SOURCE=$6
OUT=$7

for executable in "$REF_VVP" "$CANDIDATE_VVP" "$IVERILOG" "$VALGRIND"; do
  if [[ ! -x $executable ]]; then
    echo "not executable: $executable" >&2
    exit 2
  fi
done
if [[ ! -f $SOURCE || ! -d $VALGRIND_LIB ]]; then
  echo "source or Valgrind data directory is missing" >&2
  exit 2
fi
if [[ -z ${CAMPAIGN_PINNED_BASE:-} || -z ${MEASUREMENT_BASE:-} || -z ${CANDIDATE_COMMIT:-} ]]; then
  echo "measurement provenance is missing" >&2
  exit 2
fi

mkdir -p "$OUT"
WORK="$OUT/work"
mkdir "$WORK"
PROGRAM="$WORK/behav.vvp"
"$IVERILOG" -g2012 -o "$PROGRAM" "$SOURCE"

run_one() {
  local label=$1 runtime=$2
  env LC_ALL=C IVL_PERF_STATS=1 VALGRIND_LIB="$VALGRIND_LIB" \
    timeout --kill-after=5s 1200s "$VALGRIND" --quiet --tool=callgrind \
    --callgrind-out-file="$OUT/$label.callgrind" \
    --log-file="$OUT/$label.valgrind.log" \
    "$runtime" -n "$PROGRAM" +ntb_random_seed=73014 \
    >"$OUT/$label.stdout" 2>"$OUT/$label.stderr"
  awk '$1 == "summary:" { count = $2 } END { if (count == "") exit 1; print count }' \
    "$OUT/$label.callgrind" >"$OUT/$label.instructions"
}

run_one reference "$REF_VVP"
run_one candidate "$CANDIDATE_VVP"
cmp "$OUT/reference.stdout" "$OUT/candidate.stdout"
cmp "$OUT/reference.stderr" "$OUT/candidate.stderr"

REFERENCE_INSTRUCTIONS=$(<"$OUT/reference.instructions")
CANDIDATE_INSTRUCTIONS=$(<"$OUT/candidate.instructions")
INSTRUCTION_DELTA=$((CANDIDATE_INSTRUCTIONS - REFERENCE_INSTRUCTIONS))
INSTRUCTION_DELTA_PERCENT=$(awk -v ref="$REFERENCE_INSTRUCTIONS" -v cand="$CANDIDATE_INSTRUCTIONS" \
  'BEGIN { printf "%.9f", (cand - ref) * 100 / ref }')
PROGRAM_SHA=$(sha256sum "$PROGRAM" | awk '{print $1}')
SOURCE_SHA=$(sha256sum "$SOURCE" | awk '{print $1}')
REF_SHA=$(sha256sum "$REF_VVP" | awk '{print $1}')
CANDIDATE_SHA=$(sha256sum "$CANDIDATE_VVP" | awk '{print $1}')
cat >"$OUT/attempt-status.txt" <<EOF
campaign_pinned_base=$CAMPAIGN_PINNED_BASE
measurement_base=$MEASUREMENT_BASE
candidate_commit=$CANDIDATE_COMMIT
comparison=reference VVP versus compile-time-stats-off candidate VVP
benchmark=behav.sv; one shared compiled .vvp; +ntb_random_seed=73014
instruction_counter=Valgrind Callgrind Ir (hardware perf instructions unsupported)
reference_vvp_sha256=$REF_SHA
candidate_vvp_sha256=$CANDIDATE_SHA
shared_program_sha256=$PROGRAM_SHA
source_sha256=$SOURCE_SHA
reference_instructions=$REFERENCE_INSTRUCTIONS
candidate_instructions=$CANDIDATE_INSTRUCTIONS
instruction_delta=$INSTRUCTION_DELTA
instruction_delta_percent=$INSTRUCTION_DELTA_PERCENT
stdout_stderr_byte_identical=yes
instruction_count_result=measured
result=PASS
EOF
printf 'reference,candidate,delta,delta_percent\n%s,%s,%s,%s\n' \
  "$REFERENCE_INSTRUCTIONS" "$CANDIDATE_INSTRUCTIONS" \
  "$INSTRUCTION_DELTA" "$INSTRUCTION_DELTA_PERCENT" >"$OUT/result.csv"
