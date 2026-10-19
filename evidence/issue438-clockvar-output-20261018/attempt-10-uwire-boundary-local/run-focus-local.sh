#!/usr/bin/env bash
set -u

SOURCE=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue438-clockvar-output-20261018
EVIDENCE="$SOURCE/evidence/issue438-clockvar-output-20261018/attempt-10-uwire-boundary-local"
INSTALL=/tmp/ivl-a3-438-review
mkdir -p "$EVIDENCE/logs/json" "$EVIDENCE/results/json"
export PATH="$INSTALL/bin:$PATH"
cd "$SOURCE/ivtest"

status=0
perl ./vvp_reg.pl regress-vif-clocking-output-focus-legacy.list \
  > "$EVIDENCE/logs/legacy-focus.log" 2>&1
legacy_rc=$?
printf 'legacy_exit=%s\n' "$legacy_rc" > "$EVIDENCE/results/status.txt"
if [ "$legacy_rc" -ne 0 ]; then status=1; fi

: > "$EVIDENCE/results/json-status.tsv"
while IFS= read -r row; do
  case "$row" in ''|\#*) continue ;; esac
  key=$(awk '{print $1}' <<< "$row")
  one="$EVIDENCE/results/json/$key.list"
  printf '%s\n' "$row" > "$one"
  ~/codex-supervisor/localrun 180 python3 ./vvp_reg.py "$one" \
    > "$EVIDENCE/logs/json/$key.log" 2>&1
  rc=$?
  printf '%s\t%s\n' "$key" "$rc" >> "$EVIDENCE/results/json-status.tsv"
  if [ "$rc" -ne 0 ]; then status=1; fi
done < regress-vif-clocking-output-focus-vvp.list

printf 'focus_status=%s\n' "$status" >> "$EVIDENCE/results/status.txt"
exit "$status"
