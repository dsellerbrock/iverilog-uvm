#!/usr/bin/env bash
# Usage: PATH="$PWD/local-install/bin:$PATH" ./ci/run-smoke.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
status=0

while IFS= read -r name; do
    case "$name" in ''|\#*) continue ;; esac
    if ! awk -v name="$name" '$1 == name { print; found++ } END { exit found != 1 }' \
        "$ROOT/ivtest/regress-sv.list" >> "$WORK/smoke.list"; then
        echo "Smoke test is missing or duplicated: $name" >&2
        exit 2
    fi
done < "$ROOT/ci/smoke-tests.txt"

cd "$ROOT/ivtest"
perl ./vvp_reg.pl "$WORK/smoke.list" || status=1
perl ./vpi_reg.pl || status=1
cd "$ROOT"
ci/run-repros.sh || status=1

run_timed() {
    local label=$1
    shift
    echo "=== $label ==="
    python3 "$ROOT/scripts/run_with_timeout.py" 120 -- "$@" || status=1
}

echo "=== negative-suite ==="
bash "$ROOT/tests/negative/run_negative.sh" || status=1
for runner in "$ROOT"/tests/vvp_runtime/run_*; do
    case "$runner" in
        *.py) run_timed "${runner##*/}" python3 "$runner" ;;
        *.sh) run_timed "${runner##*/}" bash "$runner" ;;
    esac
done

exit "$status"
