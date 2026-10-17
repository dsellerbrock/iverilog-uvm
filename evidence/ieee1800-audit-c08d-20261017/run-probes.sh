#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
B="$ROOT/local-install/bin"
O=/tmp/a3-c08d
D="$ROOT/tests/1800_audit/c08"
FILES=(p08_13_17_inherit_super_cast p08_13_17_final_default_2023 n08_15_super_super n08_15_super_new_not_first n08_16_down_assign n08_17_extends_args_and_super_new n08_13_extend_final n08_17_default_not_subclass n08_17_default_twice n08_17_default_name_clash n08_17_super_default_without_default n08_17_default_local_member)
rm -rf "$O"
mkdir -p "$O"
rc=0
for g in 2017 2023; do
  for f in "${FILES[@]}"; do
    if [[ "$f" == n* ]]; then src="$D/neg/$f.sv"; else src="$D/$f.sv"; fi
    if [[ ! -f "$src" ]]; then printf "MISSING_SOURCE=%s\n" "$src"; rc=1; continue; fi
    obj="$O/$f.$g.vvp"
    log="$O/$f.$g.compile"
    case "$f" in n*) negative=1 ;; *) negative=0 ;; esac
    if [[ "$f" == p08_13_17_final_default_2023 && "$g" == 2017 ]]; then negative=1; fi
    printf '\n### %s -g%s\n' "$f" "$g"
    perl -e 'alarm 60; exec @ARGV' "$B/iverilog" -g"$g" -s top -o "$obj" "$src" >"$log" 2>&1
    cr=$?
    printf 'compile_rc=%d\n' "$cr"
    if [[ "$f" == n08_17_extends_args_and_super_new ]]; then
      if (( cr != 0 )); then
        printf 'UNEXPECTED_REJECTION_OF_CONFIRMED_GAP
'
        cat "$log"
        rc=1
      else
        runlog="$O/$f.$g.run"
        perl -e 'alarm 30; exec @ARGV' "$B/vvp" -n "$obj" >"$runlog" 2>&1
        rr=$?
        printf 'run_rc=%d
' "$rr"
        cat "$runlog"
        if (( rr == 0 )) && rg -q '^value=2$' "$runlog"; then
          printf 'GAP_CONFIRMED_EXTENDS_ARGUMENT_OVERRIDDEN_BY_SUPER_NEW
'
        else
          printf 'GAP_REPRO_CHANGED
'
          rc=1
        fi
      fi
      continue
    fi
    if (( negative )); then
      if (( cr == 0 || cr == 142 )); then
        printf 'EXPECTED_REJECTION_BUT_COMPILE_RC=%d\n' "$cr"
        cat "$log"
        rc=1
      else
        printf 'EXPECTED_REJECTION\n'
        cat "$log"
      fi
      continue
    fi
    if (( cr != 0 )); then
      printf 'UNEXPECTED_COMPILE_FAILURE\n'
      cat "$log"
      rc=1
      continue
    fi
    runlog="$O/$f.$g.run"
    perl -e 'alarm 30; exec @ARGV' "$B/vvp" -n "$obj" >"$runlog" 2>&1
    rr=$?
    printf 'run_rc=%d\n' "$rr"
    cat "$runlog"
    if (( rr != 0 )) || rg -q '(^| )FAIL( |$)' "$runlog"; then rc=1; fi
  done
done
printf '\nBATCH_EXIT=%d\n' "$rc"
exit "$rc"
