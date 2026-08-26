#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$(command -v iverilog 2>/dev/null || true)}
vvp=${VVP:-$(command -v vvp 2>/dev/null || true)}
source_file=ivtest/ivltests/sv_covergroup_procedural_item_options.v
expected=$script_dir/covgrp_options_report.gold
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/covgrp-options-report.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ -z "$iverilog" ] || [ ! -x "$iverilog" ]; then
    echo "error: Icarus compiler is not executable: $iverilog" >&2
    exit 2
fi
if [ -z "$vvp" ] || [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

cd "$repo_dir"
"$iverilog" -g2012 -o "$work_dir/options.vvp" "$source_file" \
    > "$work_dir/compile.stdout" 2> "$work_dir/compile.stderr"
if [ -s "$work_dir/compile.stdout" ] || \
   [ -s "$work_dir/compile.stderr" ]; then
    echo "FAIL covergroup option report: compiler produced output" >&2
    cat "$work_dir/compile.stdout" "$work_dir/compile.stderr" >&2
    exit 1
fi
dynamic_count=$(grep -c ' \.covgrp_dyn_bin ' "$work_dir/options.vvp" || true)
if [ "$dynamic_count" -ne 1 ] ||
   ! grep -Eq ' \.covgrp_dyn_bin .* "values" "setp:[0-9]+:[su][0-9]+" "setp:[0-9]+:[su][0-9]+" "[su][0-9]+" ' \
        "$work_dir/options.vvp"; then
    echo "FAIL covergroup option report: dynamic-bin metadata shape mismatch" >&2
    grep ' \.covgrp_dyn_bin ' "$work_dir/options.vvp" >&2 || true
    exit 1
fi

IVL_COVERAGE_REPORT="$work_dir/report.txt" \
    "$vvp" "$work_dir/options.vvp" \
    > "$work_dir/run.stdout" 2> "$work_dir/run.stderr"
if [ -s "$work_dir/run.stderr" ] || \
   ! printf 'PASSED\n' | cmp -s - "$work_dir/run.stdout"; then
    echo "FAIL covergroup option report: simulation output mismatch" >&2
    cat "$work_dir/run.stdout" "$work_dir/run.stderr" >&2
    exit 1
fi

awk '
  /^covergroup / &&
      ($2 ~ /__covgrp_cumulative_threshold_wrap_cg_t$/ ||
       $2 ~ /__covgrp_retired_threshold_wrap_cg_t$/) { remaining = 3 }
  remaining > 0 { print; remaining -= 1 }
' "$work_dir/report.txt" > "$work_dir/report-selected"
tr -d '\r' < "$expected" > "$work_dir/expected-normalized"
tr -d '\r' < "$work_dir/report-selected" > "$work_dir/report-normalized"
if ! cmp -s "$work_dir/expected-normalized" "$work_dir/report-normalized"; then
    echo "FAIL covergroup option report: cumulative threshold mismatch" >&2
    diff -u "$work_dir/expected-normalized" \
        "$work_dir/report-normalized" >&2 || true
    exit 1
fi

echo "PASS covergroup procedural option/report invariants (3/3)"
