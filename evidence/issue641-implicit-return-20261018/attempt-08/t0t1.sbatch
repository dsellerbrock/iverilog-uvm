#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a3-i641-t0t1
#SBATCH --cpus-per-task=3
#SBATCH --mem=5G
#SBATCH --time=00:40:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/issue641-candidate-20261018-03/logs/%x-%j.out
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/issue641-candidate-20261018-03/src
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/issue641-candidate-20261018-03
SRC="$RUN/src"
PREFIX="$SRC/local-install"
LOGS="$RUN/logs"
status=0
mkdir -p "$LOGS"

{
    printf 'base=c344d20197a569dea8936bad95de3d185b1e78dc\n'
    sha256sum "$RUN/full-change.patch" "$SRC/parse.y" \
        "$SRC/ivtest/ivltests/sv_class_extern_implicit_return.v" \
        "$SRC/ivtest/ivltests/sv_class_extern_implicit_return_2017.v" \
        "$SRC/ivtest/ivltests/sv_class_extern_implicit_return_2023.v" \
        "$SRC/ivtest/vvp_tests/sv_class_extern_implicit_return_2017.json" \
        "$SRC/ivtest/vvp_tests/sv_class_extern_implicit_return_2023.json"
    printf 'resources=3 CPUs, 5 GiB, 40 minutes\n'
} > "$LOGS/inputs.txt"

cd "$SRC"
if ! timeout --signal=TERM --kill-after=15s 900s ./configure --prefix="$PREFIX" > "$LOGS/configure.log" 2>&1; then
    printf 'configure=FAIL\n' >> "$LOGS/results.txt"
    exit 1
fi
if ! timeout --signal=TERM --kill-after=15s 1800s make -j3 > "$LOGS/make.log" 2>&1; then
    printf 'build=FAIL\n' >> "$LOGS/results.txt"
    exit 1
fi
if ! timeout --signal=TERM --kill-after=15s 900s make install > "$LOGS/install.log" 2>&1; then
    printf 'install=FAIL\n' >> "$LOGS/results.txt"
    exit 1
fi
printf 'build=PASS\n' >> "$LOGS/results.txt"
export PATH="$PREFIX/bin:$PATH"
sha256sum "$PREFIX/bin/iverilog" "$PREFIX/bin/vvp" >> "$LOGS/results.txt"

cd "$SRC/ivtest"
for gen in 2017 2023; do
    if timeout --signal=TERM --kill-after=5s 60s "$PREFIX/bin/iverilog" \
        -g"$gen" -s test -o "$LOGS/issue-$gen.vvp" \
        ivltests/sv_class_extern_implicit_return.v \
        > "$LOGS/issue-$gen.compile.log" 2>&1; then
        if timeout --signal=TERM --kill-after=5s 30s "$PREFIX/bin/vvp" -n \
            "$LOGS/issue-$gen.vvp" > "$LOGS/issue-$gen.run.log" 2>&1 \
            && grep -qx 'PASSED' "$LOGS/issue-$gen.run.log"; then
            printf 'issue_%s=PASS\n' "$gen" >> "$LOGS/results.txt"
        else
            printf 'issue_%s=FAIL (runtime)\n' "$gen" >> "$LOGS/results.txt"
            status=1
        fi
    else
        printf 'issue_%s=FAIL (compile)\n' "$gen" >> "$LOGS/results.txt"
        status=1
    fi
done

cd "$SRC"
if timeout --signal=TERM --kill-after=10s 1800s bash ci/run-smoke.sh > "$LOGS/smoke.log" 2>&1; then
    printf 'smoke=PASS\n' >> "$LOGS/results.txt"
else
    printf 'smoke=FAIL\n' >> "$LOGS/results.txt"
    status=1
fi

cd "$SRC/ivtest"
pattern='^sv_(class_extern_implicit_return_(2017|2023)|class_extern_task1|class_extern_ctor_const_init1|class_inherited_enum_extern|method_override_specifiers_(2017|2023)|method_override_outside_class_2023|method_override_extern_definition_specifier_2023|constraint_override_extern_mismatch_fail_2023)[[:space:]]'
grep -E "$pattern" regress-sv.list > "$RUN/t1-legacy.list"
grep -E "$pattern" regress-vvp.list > "$RUN/t1-json.list"
printf 't1_legacy_cases=%s\nt1_json_cases=%s\n' \
    "$(wc -l < "$RUN/t1-legacy.list")" "$(wc -l < "$RUN/t1-json.list")" >> "$LOGS/results.txt"
if timeout --signal=TERM --kill-after=10s 600s perl ./vvp_reg.pl "$RUN/t1-legacy.list" > "$LOGS/t1-legacy.log" 2>&1; then
    printf 't1_legacy=PASS\n' >> "$LOGS/results.txt"
else
    printf 't1_legacy=FAIL\n' >> "$LOGS/results.txt"
    status=1
fi
if timeout --signal=TERM --kill-after=10s 600s python3 ./vvp_reg.py "$RUN/t1-json.list" > "$LOGS/t1-json.log" 2>&1; then
    printf 't1_json=PASS\n' >> "$LOGS/results.txt"
else
    printf 't1_json=FAIL\n' >> "$LOGS/results.txt"
    status=1
fi

printf 'runner_status=%d\n' "$status" >> "$LOGS/results.txt"
exit "$status"
