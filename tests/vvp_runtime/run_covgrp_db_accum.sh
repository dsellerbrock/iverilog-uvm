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

    legacy="$work_dir/state-v1-$edition.db"
    legacy_out="$work_dir/v1-$edition.stdout"
    legacy_err="$work_dir/v1-$edition.stderr"
    if python3 "$script_dir/covgrp_db_corrupt.py" "$seed" "$legacy" legacy-v1; then
        set +e
        run_vvp "$image" "+DB=$legacy" "+LOADDB=$legacy" +QUERY_FIRST \
            >"$legacy_out" 2>"$legacy_err"
        legacy_rc=$?
        set -e
        if [ "$legacy_rc" -ne 0 ] || ! grep -Fxq 'PRE=41.67' "$legacy_out" ||
           ! grep -Fxq 'COV=41.67' "$legacy_out" ||
           grep -Fq 'ERROR: $load_coverage_db:' "$legacy_err"; then
            echo "FAIL $edition legacy version-1 merged database load"
            cat "$legacy_out" "$legacy_err"
            failures=$((failures + 1))
        else
            echo "PASS $edition legacy version-1 merged database load"
        fi
    else
        echo "FAIL $edition: could not create version-1 compatibility fixture"
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

run_default_instance_case() {
    label=$1
    expected=$2
    pre_expected=$3
    image=$4
    db=$5
    shift 5
    out="$work_dir/$label-default.stdout"
    err="$work_dir/$label-default.stderr"
    set +e
    run_vvp "$image" "$@" >"$out" 2>"$err"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] || ! grep -Fxq "COV=$expected" "$out" ||
       [ -s "$err" ] || { [ -n "$pre_expected" ] &&
       ! grep -Fxq "PRE=$pre_expected" "$out"; } || [ ! -s "$db" ]; then
        echo "FAIL $label default-instance database: rc=$rc expected=COV=$expected"
        cat "$out" "$err"
        failures=$((failures + 1))
    else
        echo "PASS $label default-instance database: COV=$expected"
    fi
}

run_default_corrupt() {
    seed=$1
    case_name=$2
    image=$3
    bad="$work_dir/$edition-$case_name.db"
    before="$work_dir/$edition-$case_name.before.db"
    out="$work_dir/$edition-$case_name.stdout"
    err="$work_dir/$edition-$case_name.stderr"
    if ! python3 "$script_dir/covgrp_db_corrupt.py" "$seed" "$bad" "$case_name"; then
        echo "FAIL $edition $case_name: could not construct malformed population"
        failures=$((failures + 1))
        return
    fi
    cp "$bad" "$before"
    set +e
    run_vvp "$image" "+DB=$bad" "+LOADDB=$bad" +QUERY_FIRST >"$out" 2>"$err"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ] || ! grep -Fq 'ERROR: $load_coverage_db:' "$err" ||
       ! grep -Fxq 'PRE=100.00' "$out" || ! grep -Fxq 'COV=100.00' "$out" ||
       ! cmp -s "$before" "$bad"; then
        echo "FAIL $edition $case_name: malformed population was applied or overwritten"
        cat "$out" "$err"
        failures=$((failures + 1))
    else
        echo "PASS $edition malformed population: $case_name"
    fi
}

run_default_oracle() {
    label=$1
    expected=$2
    image=$3
    db="$work_dir/$label-oracle.db"
    out="$work_dir/$label-oracle.stdout"
    err="$work_dir/$label-oracle.stderr"
    set +e
    run_vvp "$image" "+DB=$db" +S0=0 +S1=1 +DROP +S2=2 +S3=3 >"$out" 2>"$err"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] || ! grep -Fxq 'FIRST=50.00' "$out" ||
       ! grep -Fxq 'RETIRED=50.00' "$out" ||
       ! grep -Fxq "COV=$expected" "$out" || [ -s "$err" ] || [ ! -s "$db" ]; then
        echo "FAIL $label same-run population oracle: rc=$rc expected=COV=$expected"
        cat "$out" "$err"
        failures=$((failures + 1))
    else
        echo "PASS $label same-run population oracle: COV=$expected"
    fi
}

run_default_write_case() {
    label=$1
    image=$2
    db=$3
    shift 3
    out="$work_dir/$label-write.stdout"
    err="$work_dir/$label-write.stderr"
    set +e
    run_vvp "$image" "$@" >"$out" 2>"$err"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ] || [ ! -s "$db" ] || [ -s "$err" ]; then
        echo "FAIL $label default-instance save: rc=$rc"
        cat "$out" "$err"
        failures=$((failures + 1))
    else
        echo "PASS $label default-instance save"
    fi
}

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-default-$edition.vvp"
    if ! "$iverilog" -g"$edition" -o "$image" \
        "$script_dir/covgrp_db_default_instances.sv"; then
        echo "FAIL: compile default-instance reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi
    first="$work_dir/default-$edition-a.db"
    second="$work_dir/default-$edition-b.db"
    third="$work_dir/default-$edition-c.db"
    run_default_instance_case "$edition-A" 50.00 "" "$image" "$first" \
        "+DB=$first" +S0=0 +S1=1
    if [ -s "$first" ]; then
        for case_name in duplicate-pop missing-pop legacy-v1 merge-mismatch \
            pop-nan pop-infinity pop-zero-weight-positive \
            pop-item-zero-weight-positive \
            pop-negative pop-over-100 pop-fractional-weight pop-vector-length \
            pop-item-over-100 pop-invalid-bin-flag pop-invalid-at-least; do
            run_default_corrupt "$first" "$case_name" "$image"
        done
        run_default_instance_case "$edition-B" 50.00 50.00 "$image" "$second" \
            "+DB=$second" "+LOADDB=$first" +QUERY_FIRST +S0=2 +S1=3
    fi
    if [ -s "$second" ]; then
        run_default_instance_case "$edition-C" 50.00 50.00 "$image" "$third" \
            "+DB=$third" "+LOADDB=$second" +QUERY_FIRST
    fi

    retired="$work_dir/default-$edition-retired.db"
    mixed="$work_dir/default-$edition-mixed.db"
    mixed_again="$work_dir/default-$edition-mixed-again.db"
    run_default_instance_case "$edition-retired-A" 50.00 "" "$image" "$retired" \
        "+DB=$retired" +S0=0 +S1=1 +DROP
    if [ -s "$retired" ]; then
        run_default_instance_case "$edition-retired-B" 50.00 50.00 "$image" "$mixed" \
            "+DB=$mixed" "+LOADDB=$retired" +QUERY_FIRST +S0=2 +S1=3
    fi
    if [ -s "$mixed" ]; then
        run_default_instance_case "$edition-retired-C" 50.00 50.00 "$image" "$mixed_again" \
            "+DB=$mixed_again" "+LOADDB=$mixed" +QUERY_FIRST
    fi

    weighted_a="$work_dir/default-$edition-weighted-a.db"
    weighted_b="$work_dir/default-$edition-weighted-b.db"
    weighted_c="$work_dir/default-$edition-weighted-c.db"
    run_default_instance_case "$edition-weight-1" 25.00 "" "$image" "$weighted_a" \
        "+DB=$weighted_a" +W=1 +S0=0
    if [ -s "$weighted_a" ]; then
        run_default_instance_case "$edition-weight-3" 62.50 25.00 "$image" "$weighted_b" \
            "+DB=$weighted_b" "+LOADDB=$weighted_a" +QUERY_FIRST +W=3 \
            +S0=1 +S1=2 +S2=3
    fi
    if [ -s "$weighted_b" ]; then
        run_default_instance_case "$edition-weighted-C" 62.50 62.50 "$image" "$weighted_c" \
            "+DB=$weighted_c" "+LOADDB=$weighted_b" +QUERY_FIRST
    fi

    zero_a="$work_dir/default-$edition-zero-weight-a.db"
    zero_b="$work_dir/default-$edition-zero-weight-b.db"
    run_default_write_case "$edition-zero-weight-A" "$image" "$zero_a" \
        "+DB=$zero_a" +W=0 +S0=0 +S1=1
    if [ -s "$zero_a" ]; then
        run_default_write_case "$edition-zero-weight-B" "$image" "$zero_b" \
            "+DB=$zero_b" "+LOADDB=$zero_a" +QUERY_FIRST
    fi

    run_default_oracle "$edition-default" 50.00 "$image"
    merged_image="$work_dir/covgrp-db-class-merged-$edition.vvp"
    if "$iverilog" -g"$edition" -DMERGE_ON -o "$merged_image" \
        "$script_dir/covgrp_db_default_instances.sv"; then
        run_default_oracle "$edition-merged" 100.00 "$merged_image"
    else
        echo "FAIL: compile merged class coverage oracle -g$edition"
        failures=$((failures + 1))
    fi
done

for edition in 2017 2023; do
    image="$work_dir/covgrp-db-module-default-$edition.vvp"
    first="$work_dir/module-default-$edition-a.db"
    second="$work_dir/module-default-$edition-b.db"
    third="$work_dir/module-default-$edition-c.db"
    sampled="$work_dir/module-default-$edition-sampled.db"
    pre_sampled="$work_dir/module-default-$edition-pre-sampled.db"
    if ! "$iverilog" -g"$edition" -o "$image" \
        "$script_dir/covgrp_db_module_default_instances.sv"; then
        echo "FAIL: compile module default-instance reducer -g$edition"
        failures=$((failures + 1))
        continue
    fi
    run_default_instance_case "$edition-module-A" 50.00 "" "$image" "$first" \
        "+DB=$first" +SAMPLE=0
    if [ -s "$first" ]; then
        run_default_instance_case "$edition-module-B" 50.00 50.00 "$image" "$second" \
            "+DB=$second" "+LOADDB=$first" +QUERY_FIRST
    fi
    if [ -s "$second" ]; then
        run_default_instance_case "$edition-module-C" 50.00 50.00 "$image" "$third" \
            "+DB=$third" "+LOADDB=$second" +QUERY_FIRST
    fi
    run_default_instance_case "$edition-module-sampled" 75.00 50.00 "$image" "$sampled" \
        "+DB=$sampled" "+LOADDB=$first" +QUERY_FIRST +SAMPLE=0 +SAMPLE2=1
    run_default_instance_case "$edition-module-pre-sampled" 75.00 75.00 "$image" "$pre_sampled" \
        "+DB=$pre_sampled" "+LOADDB=$first" +QUERY_FIRST +PRE_SAMPLE=0 +PRE_SAMPLE2=1
done

if [ "$failures" -ne 0 ]; then
    echo "FAIL functional coverage database persistence ($failures checks)"
    exit 1
fi
echo "PASS functional coverage database persistence (2017/2023)"
