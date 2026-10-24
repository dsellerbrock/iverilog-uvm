#!/usr/bin/env bash
set -euo pipefail

MODE=${1:?baseline or fixed}
SOURCE_SHA=${2:?source commit}
autoconf
./configure --prefix="$PWD/local-install"
make -j3
make install
if [[ "$MODE" == fixed* ]]; then
    mkdir -p "evidence/m9-issue759-chandle-20261024/$MODE/t0"
    printf 'edition\tcompile_rc\n' > "evidence/m9-issue759-chandle-20261024/$MODE/t0/reproducer.tsv"
    for edition in 2017 2023; do
        set +e
        python3 scripts/run_with_timeout.py 120 -- \
            local-install/bin/iverilog "-g$edition" \
            -s sv_chandle_assignment_incompatible_fail \
            -o "/tmp/chandle-assignment-$edition.vvp" \
            ivtest/ivltests/sv_chandle_assignment_incompatible_fail.v \
            >"evidence/m9-issue759-chandle-20261024/$MODE/t0/reproducer-$edition.log" 2>&1
        rc=$?
        set -e
        printf '%s\t%s\n' "$edition" "$rc" \
            >> "evidence/m9-issue759-chandle-20261024/$MODE/t0/reproducer.tsv"
        [[ $rc -ne 0 ]]
    done
    PATH="$PWD/local-install/bin:$PATH" bash ci/run-smoke.sh \
        > "evidence/m9-issue759-chandle-20261024/$MODE/t0/smoke.log" 2>&1
    bash evidence/m9-issue759-chandle-20261024/run-edge-probes.sh \
        fixed "$PWD/local-install/bin/iverilog" "$PWD/local-install/bin/vvp" "$SOURCE_SHA"
fi
SOURCE_SHA="$SOURCE_SHA" bash evidence/m9-issue759-chandle-20261024/run-probes-and-collateral.sh "$MODE"
