#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/local-install/bin/vvp}
source_file=$repo_dir/ivtest/ivltests/sv_process_kill_join_reducer.v
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/process-kill-call-context.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ] || [ ! -x "$vvp" ]; then
    echo "error: compiler/runtime are not executable: $iverilog / $vvp" >&2
    exit 2
fi

"$iverilog" -g2012 -o "$work_dir/reducer.vvp" "$source_file"

check_run()
{
    label=$1
    stats=$work_dir/$label.stats
    stdout=$work_dir/$label.stdout
    stderr=$work_dir/$label.stderr
    shift

    set +e
    env "$@" IVL_CTX_STATS="$stats" "$vvp" "$work_dir/reducer.vvp" \
        > "$stdout" 2> "$stderr"
    rc=$?
    set -e

    if [ "$rc" -ne 0 ] \
       || ! grep -F -x -q PASSED "$stdout" \
       || [ "$(wc -l < "$stdout")" -ne 1 ]; then
        echo "FAIL process-kill call-context $label run (rc=$rc)" >&2
        cat "$stdout" >&2
        cat "$stderr" >&2
        exit 1
    fi
    if ! grep -F -x -q 'ctx-stats: callf.active-release=5' "$stats"; then
        echo "FAIL process-kill call-context $label release census" >&2
        cat "$stats" >&2
        exit 1
    fi
}

check_run modern
check_run legacy IVL_TRAMPOLINE_CALLF=0

echo "PASS process-kill automatic call-context release (modern + legacy)"
