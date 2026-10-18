#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$(command -v iverilog 2>/dev/null || true)}
vvp=${VVP:-$(command -v vvp 2>/dev/null || true)}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/covgrp-per-instance.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
timed() { python3 "$repo_dir/scripts/run_with_timeout.py" 60 -- "$@"; }

if [ -z "$iverilog" ] || [ ! -x "$iverilog" ] || \
   [ -z "$vvp" ] || [ ! -x "$vvp" ]; then
    echo "error: Icarus compiler and VVP runtime must be executable" >&2
    exit 2
fi

cd "$repo_dir"
for generation in 2017 2023; do
    suffix=
    [ "$generation" = 2017 ] || suffix=_2023
    source_file="ivtest/ivltests/sv_covergroup_per_instance_ctor${suffix}.v"
    if ! timed \
        "$iverilog" -g"$generation" -o "$work_dir/test-$generation.vvp" \
        "$source_file" >"$work_dir/compile-$generation.out" \
        2>"$work_dir/compile-$generation.err"; then
        echo "FAIL per-instance coverage: compile failed in -g$generation" >&2
        cat "$work_dir/compile-$generation.out" "$work_dir/compile-$generation.err" >&2
        exit 1
    fi
    if [ -s "$work_dir/compile-$generation.out" ] || \
       [ -s "$work_dir/compile-$generation.err" ]; then
        echo "FAIL per-instance coverage: compiler output in -g$generation" >&2
        cat "$work_dir/compile-$generation.out" "$work_dir/compile-$generation.err" >&2
        exit 1
    fi

    if ! IVL_COVERAGE_REPORT="$work_dir/report-$generation.txt" \
        timed "$vvp" "$work_dir/test-$generation.vvp" \
        >"$work_dir/run-$generation.out" 2>"$work_dir/run-$generation.err"; then
        echo "FAIL per-instance coverage: simulation failed in -g$generation" >&2
        cat "$work_dir/run-$generation.out" "$work_dir/run-$generation.err" >&2
        exit 1
    fi
    if [ -s "$work_dir/run-$generation.err" ] || \
       ! printf 'PASSED\n' | cmp -s - "$work_dir/run-$generation.out"; then
        echo "FAIL per-instance coverage: simulation output in -g$generation" >&2
        cat "$work_dir/run-$generation.out" "$work_dir/run-$generation.err" >&2
        exit 1
    fi

    report="$work_dir/report-$generation.txt"
    [ "$(grep -c '^  instance ' "$report")" -eq 2 ] || {
        echo "FAIL per-instance coverage: expected only the two enabled instances" >&2
        cat "$report" >&2
        exit 1
    }
    grep -Fq '  instance 1 per_instance 1 coverage 100.00' "$report" || {
        echo "FAIL per-instance coverage: retired instance not retained" >&2
        cat "$report" >&2
        exit 1
    }
    grep -Fq '  instance 2 per_instance 1 coverage 50.00' "$report" || {
        echo "FAIL per-instance coverage: live instance missing or disabled instance retained" >&2
        cat "$report" >&2
        exit 1
    }
    sed -n '/  instance 1 /,/  instance 2 /p' "$report" | \
        grep -Fq 'bin __bin_cp_zero count 1 hit' || {
            echo "FAIL per-instance coverage: retired zero bin count" >&2
            cat "$report" >&2
            exit 1
        }
    sed -n '/  instance 1 /,/  instance 2 /p' "$report" | \
        grep -Fq 'bin __bin_cp_one count 1 hit' || {
            echo "FAIL per-instance coverage: retired one bin count" >&2
            cat "$report" >&2
            exit 1
        }
    sed -n '/  instance 2 /,$p' "$report" | \
        grep -Fq 'bin __bin_cp_zero count 0 MISS' || {
            echo "FAIL per-instance coverage: live zero bin count" >&2
            cat "$report" >&2
            exit 1
        }
    sed -n '/  instance 2 /,$p' "$report" | \
        grep -Fq 'bin __bin_cp_one count 1 hit' || {
            echo "FAIL per-instance coverage: live one bin count" >&2
            cat "$report" >&2
            exit 1
        }

    negative="ivtest/ivltests/sv_covergroup_per_instance_write_fail${suffix}.v"
    if timed \
        "$iverilog" -g"$generation" -o "$work_dir/negative-$generation.vvp" \
        "$negative" >"$work_dir/negative-$generation.out" \
        2>"$work_dir/negative-$generation.err"; then
        echo "FAIL per-instance coverage: procedural write compiled in -g$generation" >&2
        exit 1
    fi
    grep -Fq 'option.per_instance can only be set in a covergroup definition.' \
        "$work_dir/negative-$generation.err" || {
            echo "FAIL per-instance coverage: procedural-write diagnostic missing" >&2
            cat "$work_dir/negative-$generation.err" >&2
            exit 1
        }
done

echo "PASS per-instance constructor options and report retention (4/4)"
