#!/bin/bash
set -euo pipefail

evidence=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$evidence/../../.." && pwd)
tmp=$(mktemp -d /tmp/a3-c14-build.XXXXXX)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$evidence/results"

commit=$(git -C "$repo" rev-parse origin/main)
printf 'source_commit=%s\n' "$commit" | tee "$evidence/results/source.txt"
git -C "$repo" archive "$commit" | tar -x -C "$tmp"
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
cd "$tmp"
sh autoconf.sh >"$evidence/results/autoconf.log" 2>&1
./configure --prefix="$tmp/install" >"$evidence/results/configure.log" 2>&1
/usr/bin/time -v make -j3 >"$evidence/results/build.log" 2>&1
make install >"$evidence/results/install.log" 2>&1
iverilog="$tmp/install/bin/iverilog"
vvp="$tmp/install/bin/vvp"
python="$tmp/scripts/run_with_timeout.py"
{
    "$iverilog" -V | head -1
    shasum -a 256 "$iverilog" "$vvp"
} | tee "$evidence/results/toolchain.txt"

tests="$repo/tests/1800_audit/c14"
status=0

positive() {
    local name=$1 edition=$2 stem="$tmp/$1-$2"
    if ! python3 "$python" 120 -- "$iverilog" "-g$edition" -o "$stem.vvp" "$tests/$name.sv" \
        >"$evidence/results/$stem.compile.log" 2>&1; then
        echo "FAIL compile expected pass: $name -g$edition" | tee -a "$evidence/results/matrix.txt"
        status=1
        return
    fi
    if ! python3 "$python" 120 -- "$vvp" "$stem.vvp" \
        >"$evidence/results/$stem.run.log" 2>&1 || ! grep -q '^PASSED$' "$evidence/results/$stem.run.log"; then
        echo "FAIL run expected pass: $name -g$edition" | tee -a "$evidence/results/matrix.txt"
        status=1
        return
    fi
    echo "PASS: $name -g$edition" | tee -a "$evidence/results/matrix.txt"
}

reject() {
    local name=$1 edition=$2 stem="$tmp/${1//\//-}-$2" rc
    if python3 "$python" 120 -- "$iverilog" "-g$edition" -o "$stem.vvp" "$tests/$name.sv" \
        >"$evidence/results/$stem.compile.log" 2>&1; then
        echo "FAIL compile expected rejection: $name -g$edition" | tee -a "$evidence/results/matrix.txt"
        status=1
    else
        rc=$?
        if [[ $rc -eq 124 ]]; then
            echo "FAIL compile timed out: $name -g$edition" | tee -a "$evidence/results/matrix.txt"
            status=1
        else
            echo "REJECTED: $name -g$edition (exit $rc)" | tee -a "$evidence/results/matrix.txt"
        fi
    fi
}

: > "$evidence/results/matrix.txt"
positive p14_03_clocking_decl 2023
positive p14_03_clocking_decl_2017 2017
positive p14_03_clocking_decl_2017 2023
positive p14_03_end_label 2017
positive p14_03_end_label 2023
positive p14_03_zero_output_skew 2023
reject p14_03_clocking_decl 2017
reject p14_03_zero_output_skew 2017
for name in n14_03_write_input n14_03_read_output n14_03_unnamed_nondefault; do
    reject "neg/$name" 2017
    reject "neg/$name" 2023
done

exit "$status"
