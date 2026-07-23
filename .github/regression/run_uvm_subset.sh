#!/usr/bin/env bash
# Run a subset of the UVM suite (Tier 2/3 of the cost-aware regression system).
#
# Usage:
#   run_uvm_subset.sh <list-file>            # file of test names (smoke.list)
#   run_uvm_subset.sh <name> [<name>...]     # explicit test names
#   run_uvm_subset.sh --group <group>        # expand a groups.conf subsystem
#
# Builds a temp dir of symlinks into tests/ and invokes .github/uvm_test.sh
# with UVM_TESTS_DIR pointing at it. Exit status is uvm_test.sh's.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TESTS="$REPO/tests"
GROUPS_CONF="$REPO/.github/regression/groups.conf"
names=()
if [ "${1:-}" = "--group" ]; then
    grp="${2:?group name required}"
    line=$(grep -E "^${grp}:" "$GROUPS_CONF" | head -1)
    [ -n "$line" ] || { echo "unknown group: $grp" >&2; exit 2; }
    for pat in ${line#*:}; do
        for f in "$TESTS"/$pat.sv "$TESTS"/$pat; do
            [ -e "$f" ] || continue
            case "$f" in *.sv) names+=("$(basename "$f" .sv)");; esac
        done
    done
elif [ -f "${1:-}" ] && grep -qvE '^\s*(#|$)' "$1" 2>/dev/null && [[ "$1" == *list* || "$1" == */regression/* ]]; then
    while IFS= read -r ln; do
        ln="${ln%%#*}"; ln="$(echo "$ln" | tr -d '[:space:]')"
        [ -n "$ln" ] && names+=("$ln")
    done < "$1"
else
    names=("$@")
fi
[ ${#names[@]} -gt 0 ] || { echo "no tests selected" >&2; exit 2; }
# de-dup
mapfile -t names < <(printf '%s\n' "${names[@]}" | sort -u)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
missing=0
for n in "${names[@]}"; do
    if [ -f "$TESTS/$n.sv" ]; then
        ln -s "$TESTS/$n.sv" "$dir/"
        [ -f "$TESTS/$n.c" ] && ln -s "$TESTS/$n.c" "$dir/"
    else
        echo "WARNING: no such test: $n" >&2; missing=1
    fi
done
echo "== UVM subset: ${#names[@]} tests =="
UVM_TESTS_DIR="$dir" bash "$REPO/.github/uvm_test.sh"
rc=$?
[ $missing -ne 0 ] && echo "NOTE: some requested tests were missing (see warnings)" >&2
exit $rc
