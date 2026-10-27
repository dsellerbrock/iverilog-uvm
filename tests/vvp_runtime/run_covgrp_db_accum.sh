#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$(command -v iverilog 2>/dev/null || true)}
vvp=${VVP:-$(command -v vvp 2>/dev/null || true)}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/covgrp-db-accum.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ -z "$iverilog" ] || [ ! -x "$iverilog" ] ||
   [ -z "$vvp" ] || [ ! -x "$vvp" ]; then
    echo "error: set IVERILOG and VVP to executable paths" >&2
    exit 2
fi

cd "$repo_dir"
failures=0

run_vvp() {
    python3 "$repo_dir/scripts/run_with_timeout.py" "${IVL_TEST_TIMEOUT:-120}" -- "$vvp" "$@"
}

run_ok() {
    run_label=$1
    run_expected=$2
    run_pre_expected=$3
    run_image=$4
    shift 4
    run_out="$work_dir/$run_label.stdout"
    run_err="$work_dir/$run_label.stderr"
    set +e
    run_vvp "$run_image" "$@" >"$run_out" 2>"$run_err"
    rc=$?
    set -e
    printf '%s exit=%s expected=COV=%s\n' "$run_label" "$rc" "$run_expected"
    cat "$run_out" "$run_err"
    if [ "$rc" -ne 0 ] || ! grep -Fxq "COV=$run_expected" "$run_out" ||
       grep -q 'ERROR: database existed before simulation end' "$run_out" ||
       [ -s "$run_err" ]; then
        failures=$((failures + 1))
    fi
    if [ -n "$run_pre_expected" ] &&
       ! grep -Fxq "PRE=$run_pre_expected" "$run_out"; then
        failures=$((failures + 1))
    fi
}

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-$edition.vvp"
    state="$work_dir/state-$edition.db"
    if ! "$iverilog" -g"$edition" -o "$image" \
        "$script_dir/covgrp_db_accum.sv"; then
        echo "FAIL: compile accumulation reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi

    out="$work_dir/first-$edition.db"
    run_ok "$edition-A" 50.00 "" "$image" "+DB=$out" +CHECK_EMPTY +S0=0 +S1=1
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/second-$edition.db"
    run_ok "$edition-B" 75.00 50.00 "$image" "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST +S0=2
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/third-$edition.db"
    run_ok "$edition-C" 100.00 75.00 "$image" "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST +S0=3
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/isolated-$edition.db"
    run_ok "$edition-D" 25.00 "" "$image" "+DB=$out" +CHECK_EMPTY +S0=0

    if [ -s "$state" ]; then
        mismatch="$work_dir/mismatch-$edition.vvp"
        snapshot="$work_dir/state-before-mismatch-$edition.db"
        "$iverilog" -g"$edition" -o "$mismatch" \
            "$script_dir/covgrp_db_accum_v2.sv" || {
                echo "FAIL: compile mismatch reducer -g$edition"
                failures=$((failures + 1))
                continue
            }
        cp "$state" "$snapshot"
        out="$work_dir/mismatch-$edition.stdout"
        err="$work_dir/mismatch-$edition.stderr"
        set +e
        run_vvp "$mismatch" "+DB=$state" "+LOADDB=$state" +S0=4 \
            >"$out" 2>"$err"
        rc=$?
        set -e
        printf '%s mismatch exit=%s expected=COV=25.00\n' "$edition"
        cat "$out" "$err"
        if [ "$rc" -eq 0 ] || ! grep -Fxq 'COV=25.00' "$out" ||
           ! cmp -s "$snapshot" "$state"; then
            failures=$((failures + 1))
        fi
    else
        echo "SKIP $edition mismatch reducer: no database was saved"
    fi
done

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-dynamic-$edition.vvp"
    state="$work_dir/state-dynamic-$edition.db"
    if ! "$iverilog" -g"$edition" -DCOVDB_DYNAMIC -o "$image" \
        "$script_dir/covgrp_db_accum.sv"; then
        echo "FAIL: compile dynamic accumulation reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi

    out="$work_dir/first-dynamic-$edition.db"
    run_ok "$edition-dynamic-A" 50.00 "" "$image" \
        "+DB=$out" +CHECK_EMPTY +S0=0 +S1=1
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/second-dynamic-$edition.db"
    run_ok "$edition-dynamic-B" 75.00 50.00 "$image" \
        "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST +S0=2
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/third-dynamic-$edition.db"
    run_ok "$edition-dynamic-C" 100.00 75.00 "$image" \
        "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST +S0=3
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/isolated-dynamic-$edition.db"
    run_ok "$edition-dynamic-D" 25.00 "" "$image" \
        "+DB=$out" +CHECK_EMPTY +S0=0

    if [ -s "$state" ]; then
        mismatch="$work_dir/mismatch-dynamic-$edition.vvp"
        snapshot="$work_dir/state-before-mismatch-dynamic-$edition.db"
        "$iverilog" -g"$edition" -DCOVDB_DYNAMIC -DCOVDB_MISMATCH -o "$mismatch" \
            "$script_dir/covgrp_db_accum_v2.sv" || {
                echo "FAIL: compile dynamic mismatch reducer -g$edition"
                failures=$((failures + 1))
                continue
            }
        cp "$state" "$snapshot"
        out="$work_dir/mismatch-dynamic-$edition.stdout"
        err="$work_dir/mismatch-dynamic-$edition.stderr"
        set +e
        run_vvp "$mismatch" "+DB=$state" "+LOADDB=$state" +S0=4 \
            >"$out" 2>"$err"
        rc=$?
        set -e
        printf '%s dynamic mismatch exit=%s expected=COV=25.00\n' "$edition"
        cat "$out" "$err"
        if [ "$rc" -eq 0 ] || ! grep -Fxq 'COV=25.00' "$out" ||
           ! cmp -s "$snapshot" "$state"; then
            failures=$((failures + 1))
        fi
    else
        echo "SKIP $edition dynamic mismatch reducer: no database was saved"
    fi
done

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-sized-$edition.vvp"
    state="$work_dir/state-sized-$edition.db"
    if ! "$iverilog" -g"$edition" -DCOVDB_DYNAMIC -DCOVDB_SIZED \
        -o "$image" "$script_dir/covgrp_db_accum.sv"; then
        echo "FAIL: compile sized dynamic reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi

    out="$work_dir/first-sized-$edition.db"
    run_ok "$edition-sized-A" 50.00 "" "$image" \
        "+DB=$out" +CHECK_EMPTY +S0=0
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/second-sized-$edition.db"
    run_ok "$edition-sized-B" 100.00 50.00 "$image" \
        "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST +S0=2
done

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-dynamic-atleast2-$edition.vvp"
    state="$work_dir/state-dynamic-atleast2-$edition.db"
    if ! "$iverilog" -g"$edition" -DCOVDB_DYNAMIC -DCOVDB_ATLEAST2 \
        -o "$image" "$script_dir/covgrp_db_accum.sv"; then
        echo "FAIL: compile dynamic at_least reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi

    out="$work_dir/first-dynamic-atleast2-$edition.db"
    run_ok "$edition-dynamic-atleast2-A" 0.00 "" "$image" \
        "+DB=$out" +CHECK_EMPTY +S0=0
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/second-dynamic-atleast2-$edition.db"
    run_ok "$edition-dynamic-atleast2-B" 25.00 0.00 "$image" \
        "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST +S0=0
done

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-cross-$edition.vvp"
    state="$work_dir/state-cross-$edition.db"
    if ! "$iverilog" -g"$edition" -o "$image" \
        "$script_dir/covgrp_db_cross.sv"; then
        echo "FAIL: compile cross persistence reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi

    out="$work_dir/first-cross-$edition.db"
    run_ok "$edition-cross-A" 41.67 "" "$image" \
        "+DB=$out" +CHECK_EMPTY +LO=2 +HI=3 +LEFT=2 +RIGHT=3
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/second-cross-pre-$edition.db"
    run_ok "$edition-cross-B-pre" 38.89 41.67 "$image" \
        "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST \
        +LO=0 +HI=2 +LEFT=0 +RIGHT=0

    out="$work_dir/second-cross-order-$edition.db"
    run_ok "$edition-cross-B-order" 38.89 "" "$image" \
        "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +LOAD_AFTER \
        +LO=0 +HI=2 +LEFT=0 +RIGHT=0
done

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-trans-$edition.vvp"
    state="$work_dir/state-trans-$edition.db"
    if ! "$iverilog" -g"$edition" -o "$image" \
        "$script_dir/covgrp_db_trans.sv"; then
        echo "FAIL: compile transition persistence reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi

    out="$work_dir/first-trans-$edition.db"
    run_ok "$edition-trans-A" 0.00 "" "$image" \
        "+DB=$out" +CHECK_EMPTY +LO=0 +HI=1
    if [ -s "$out" ]; then cp "$out" "$state"; fi

    out="$work_dir/second-trans-$edition.db"
    run_ok "$edition-trans-B" 33.33 0.00 "$image" \
        "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST +LO=2 +HI=3
done

for edition in 2017 2023; do
    for threshold in 1 2; do
        image="$work_dir/covgrp-db-static-trans-$edition-$threshold.vvp"
        state="$work_dir/state-static-trans-$edition-$threshold.db"
        if [ "$threshold" -eq 2 ]; then
            threshold_define=-DCOVDB_ATLEAST2
        else
            threshold_define=
        fi
        if ! "$iverilog" -g"$edition" $threshold_define -o "$image" \
            "$script_dir/covgrp_db_static_trans.sv"; then
            echo "FAIL: compile static transition reducer -g$edition at_least=$threshold"
            failures=$((failures + 1))
            continue
        fi

        out="$work_dir/first-static-trans-$edition-$threshold.db"
        if [ "$threshold" -eq 2 ]; then
            run_ok "$edition-static-trans-atleast2-A" 0.00 "" "$image" \
                "+DB=$out" +CHECK_EMPTY +SEQ=same
            expected=33.33
            pre_expected=0.00
            sequence=same
        else
            run_ok "$edition-static-trans-A" 33.33 "" "$image" \
                "+DB=$out" +CHECK_EMPTY +SEQ=first
            expected=66.67
            pre_expected=33.33
            sequence=second
        fi
        if [ -s "$out" ]; then cp "$out" "$state"; fi

        out="$work_dir/second-static-trans-$edition-$threshold.db"
        run_ok "$edition-static-trans-B-$threshold" "$expected" "$pre_expected" \
            "$image" "+DB=$out" "+LOADDB=$state" +CHECK_EMPTY +QUERY_FIRST \
            "+SEQ=$sequence"
    done
done

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-corrupt-$edition.vvp"
    seed="$work_dir/state-corrupt-$edition.db"
    seed_again="$work_dir/state-corrupt-again-$edition.db"
    if ! "$iverilog" -g"$edition" -o "$image" \
        "$script_dir/covgrp_db_corrupt.sv"; then
        echo "FAIL: compile corrupt database reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi

    run_ok "$edition-corrupt-seed" 41.67 "" "$image" "+DB=$seed"
    run_ok "$edition-corrupt-seed-again" 41.67 "" "$image" "+DB=$seed_again"
    if ! cmp -s "$seed" "$seed_again"; then
        echo "FAIL $edition deterministic save: identical simulations wrote different databases"
        failures=$((failures + 1))
    fi

    run_corrupt() {
        case_source=$1
        case_name=$2
        case_image=$3
        expected_pre=$4
        shift 4
        bad="$work_dir/$edition-$case_name.db"
        before="$work_dir/$edition-$case_name.before.db"
        out="$work_dir/$edition-$case_name.stdout"
        err="$work_dir/$edition-$case_name.stderr"
        python3 "$script_dir/covgrp_db_corrupt.py" "$case_source" "$bad" "$case_name" || {
            echo "FAIL $edition $case_name: could not construct malformed database"
            failures=$((failures + 1))
            return
        }
        cp "$bad" "$before"
        set +e
        run_vvp "$case_image" "+DB=$bad" "+LOADDB=$bad" +QUERY_FIRST "$@" >"$out" 2>"$err"
        rc=$?
        set -e
        if [ "$rc" -eq 0 ] || ! grep -Fq 'ERROR: $load_coverage_db:' "$err" ||
           ! grep -Fxq "PRE=$expected_pre" "$out" || ! cmp -s "$before" "$bad"; then
            echo "FAIL $edition $case_name: rc=$rc; malformed load must be rejected without applying or overwriting"
            cat "$out" "$err"
            failures=$((failures + 1))
        else
            echo "PASS $edition malformed database: $case_name"
        fi
    }

    for case_name in duplicate-dyn adjacent-range sized-index-outside-total \
        unknown-dyn-family dyn-count-overflow sord-dynamic-family \
        sord-unknown-family sord-out-of-range duplicate-sord \
        sord-count-overflow duplicate-total; do
        run_corrupt "$seed" "$case_name" "$image" 100.00
    done

    cross_image="$work_dir/covgrp-db-cross-$edition.vvp"
    for case_name in duplicate-cross cross-count-overflow \
        cross-dynamic-value-outside-range duplicate-cross-named; do
        run_corrupt "$work_dir/state-cross-$edition.db" "$case_name" \
            "$cross_image" 100.00 +LO=0 +HI=2 +LEFT=0 +RIGHT=0
    done
    trans_image="$work_dir/covgrp-db-trans-$edition.vvp"
    for case_name in duplicate-trans trans-count-overflow; do
        run_corrupt "$work_dir/state-trans-$edition.db" "$case_name" \
            "$trans_image" 100.00 +LO=0 +HI=1
    done
done

if [ "$failures" -ne 0 ]; then
    echo "FAIL functional coverage database persistence ($failures checks)"
    exit 1
fi
echo "PASS functional coverage database persistence (2017/2023)"
