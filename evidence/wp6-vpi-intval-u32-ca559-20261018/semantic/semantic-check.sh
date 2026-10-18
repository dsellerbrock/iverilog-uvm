#!/usr/bin/env bash
set -Eeuo pipefail
REF=$1
CAND=$2
INPUT=$3
OUT=$4
exec bash "$INPUT/check-intval.sh" "$REF" "$CAND" "$INPUT" "$OUT"
