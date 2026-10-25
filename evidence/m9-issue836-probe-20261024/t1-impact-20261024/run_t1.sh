#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
T1="$ROOT/evidence/m9-issue836-probe-20261024/t1-impact-20261024"
RESULTS="$T1/t1-results"
UVM_SRC=/home/dsell/toolchains/uvm-core-78c06547a2a0a29b3dc9dcafae62b75b2ff61544
mkdir -p "$RESULTS"

if [ ! -f "$ROOT/uvm-core/src/uvm_pkg.sv" ]; then
    [ ! -d "$ROOT/uvm-core" ] || rmdir "$ROOT/uvm-core"
    ln -s "$UVM_SRC" "$ROOT/uvm-core"
fi

cd "$ROOT"
autoconf
./configure --enable-libveriuser --prefix="$ROOT/local-install"
make -j3
make install
export PATH="$ROOT/local-install/bin:$PATH"

cd "$ROOT/ivtest"
set +e
perl ./vvp_reg.pl "$T1/a3-836-t1-legacy.list" > "$RESULTS/legacy.log" 2>&1
legacy_rc=$?
set -e

json_total=0
json_passed=0
: > "$RESULTS/json.log"
: > "$RESULTS/json-failed.list"
while IFS= read -r row; do
    [ -n "$row" ] || continue
    json_total=$((json_total + 1))
    name=${row%%$'\t'*}
    printf '%s\n' "$row" > "$RESULTS/one-json.list"
    set +e
    python3 "$ROOT/scripts/run_with_timeout.py" 300 -- python3 ./vvp_reg.py "$RESULTS/one-json.list" >> "$RESULTS/json.log" 2>&1
    json_rc=$?
    set -e
    if [ "$json_rc" -eq 0 ]; then
        json_passed=$((json_passed + 1))
    else
        printf '%s\n' "$name" >> "$RESULTS/json-failed.list"
    fi
done < "$T1/a3-836-t1-json.list"

cd "$ROOT"
set +e
python3 scripts/run_with_timeout.py 3600 -- bash .github/uvm_test.sh > "$RESULTS/uvm.log" 2>&1
uvm_rc=$?
set -e
printf 'legacy_rc=%s list=%s\njson=%s/%s passed\nuvm_rc=%s\n' \
    "$legacy_rc" "$T1/a3-836-t1-legacy.list" "$json_passed" "$json_total" "$uvm_rc" \
    > "$RESULTS/summary.txt"
[ "$legacy_rc" -eq 0 ] && [ "$json_passed" -eq "$json_total" ] && [ "$uvm_rc" -eq 0 ]
