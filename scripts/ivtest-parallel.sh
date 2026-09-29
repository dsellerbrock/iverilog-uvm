#!/bin/bash
#
# Run the JSON ivtest harness (ivtest/vvp_reg.py) on several cores.
#
# usage: scripts/ivtest-parallel.sh [-j JOBS] [LIST...]
#
# The harness compiles every test to ivtest/work/a.out and writes
# ivtest/log/, so two copies cannot share one directory. This script splits
# the listed tests round-robin into JOBS shards, runs the unmodified harness
# on each shard in a private copy of ivtest/ (made inside the repository, so
# tests that include ../tests/... still resolve), then prints every shard's
# per-test lines in list order with one combined total. The exit status is
# nonzero if any test failed or a shard produced no total.
#
# LIST defaults to ivtest/regress-vvp.list. Only the JSON harness is
# supported: the legacy Perl harness adds -S to its synthesis lists only
# when run without an explicit list, so sharding it would change what runs.
#
# Put the compiler under test first on PATH as an absolute path, e.g.
#   PATH="$PWD/local-install/bin:$PATH" scripts/ivtest-parallel.sh -j 4

set -u
JOBS=$(nproc 2>/dev/null || echo 2)
while getopts "j:" opt; do
      case $opt in
	    j) JOBS=$OPTARG ;;
	    *) echo "usage: $0 [-j JOBS] [LIST...]" >&2; exit 2 ;;
      esac
done
shift $((OPTIND - 1))

REPO=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO/ivtest" || exit 2
LISTS=("$@")
[ ${#LISTS[@]} -eq 0 ] && LISTS=(regress-vvp.list)

WORKROOT=$(mktemp -d "$REPO/.ivtest-parallel.XXXXXX")
trap 'rm -rf "$WORKROOT"' EXIT

# One entry per test, comments and blank lines dropped. A name listed more
# than once is run once, as vvp_reg.py does: at its first position, with its
# last entry.
cat "${LISTS[@]}" | sed -e 's/#.*//' -e '/^[[:space:]]*$/d' \
      | awk '{ if (!($1 in last)) order[n++] = $1; last[$1] = $0 }
	     END { for (i = 0; i < n; i++) print last[order[i]] }' \
      > "$WORKROOT/all.list"
TOTAL=$(wc -l < "$WORKROOT/all.list")
[ "$TOTAL" -gt 0 ] || { echo "no tests listed" >&2; exit 2; }
[ "$JOBS" -gt "$TOTAL" ] && JOBS=$TOTAL

for ((k = 0; k < JOBS; k++)); do
      mkdir -p "$WORKROOT/shard$k"
      # Copy the harness tree but not stale logs or work files, nor a
      # vsim left by an interrupted legacy vvp_reg.pl run: some tests
      # (pr2509349a) look for a file of that name.
      tar -C "$REPO/ivtest" --exclude=./log --exclude=./work \
	    --exclude=./vsim -cf - . \
	    | tar -C "$WORKROOT/shard$k" -xf -
      mkdir -p "$WORKROOT/shard$k/log" "$WORKROOT/shard$k/work"
      awk -v k=$k -v n=$JOBS '(NR - 1) % n == k' "$WORKROOT/all.list" \
	    > "$WORKROOT/shard$k/shard.list"
done

# Some tests include ../tests/..., so each copy sits in a directory whose
# other entries are symlinks to the repository's top level.
for ((k = 0; k < JOBS; k++)); do
      mkdir -p "$WORKROOT/root$k"
      for entry in "$REPO"/*; do
	    base=$(basename "$entry")
	    [ "$base" = ivtest ] && continue
	    ln -s "$entry" "$WORKROOT/root$k/$base"
      done
      mv "$WORKROOT/shard$k" "$WORKROOT/root$k/ivtest"
done

for ((k = 0; k < JOBS; k++)); do
      ( cd "$WORKROOT/root$k/ivtest" \
	      && python3 ./vvp_reg.py shard.list > "$WORKROOT/out$k.txt" 2>&1 ) &
done
wait

# Print the per-test lines in list order and sum the totals.
RAN=0; FAILED=0; MISSING=0
while read -r name _; do
      for ((k = 0; k < JOBS; k++)); do
	    line=$(grep -E "^[[:space:]]*${name}: " "$WORKROOT/out$k.txt" | head -1)
	    if [ -n "$line" ]; then
		  echo "$line"
		  break
	    fi
      done
      if [ -z "$line" ]; then
	    echo "$name: no result"
	    MISSING=$((MISSING + 1))
      fi
done < "$WORKROOT/all.list"

for ((k = 0; k < JOBS; k++)); do
      t=$(grep -E "^Test results: Ran [0-9]+, Failed [0-9]+" "$WORKROOT/out$k.txt")
      if [ -z "$t" ]; then
	    echo "shard $k produced no total:" >&2
	    tail -5 "$WORKROOT/out$k.txt" >&2
	    MISSING=$((MISSING + 1))
	    continue
      fi
      RAN=$((RAN + $(echo "$t" | sed -E 's/.*Ran ([0-9]+).*/\1/')))
      FAILED=$((FAILED + $(echo "$t" | sed -E 's/.*Failed ([0-9]+).*/\1/')))
done

echo "============================================================================"
echo "Test results: Ran $RAN, Failed $FAILED. ($JOBS shards)"
[ "$FAILED" -eq 0 ] && [ "$MISSING" -eq 0 ]
