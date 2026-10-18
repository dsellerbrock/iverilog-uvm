#!/usr/bin/env bash
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/issue418-joint-20261017-t0t1-05
SRC="$RUN_DIR/source"
RESULTS="$RUN_DIR/results"
mkdir -p "$SRC" "$RESULTS"
exec > >(tee -a "$RESULTS/combined.log") 2>&1
trap 'rc=$?; printf "body_exit=%s\n" "$rc" > "$RESULTS/body.exit"; if [ -d "$SRC/ivtest/log" ]; then tar -czf "$RESULTS/ivtest-logs.tar.gz" -C "$SRC" ivtest/log ivtest/vpi_log 2>/dev/null || true; fi' EXIT
printf 'HEAD=9b5fad2afb4104caa816b257d5bccc40f01b8c66\n'
printf 'PATCH_SHA256='
sha256sum "$RUN_DIR/a3-issue418.patch"
printf 'HOST='
hostname
uname -a
mkdir -p "$SRC"
tar -xzf "$RUN_DIR/a3-issue418-base.tar.gz" -C "$SRC"
cd "$SRC"
patch --batch --forward -p1 < "$RUN_DIR/a3-issue418.patch"
python3 scripts/run_with_timeout.py 120 -- autoconf
python3 scripts/run_with_timeout.py 300 -- ./configure --enable-libveriuser --prefix="$SRC/local-install"
python3 scripts/run_with_timeout.py 900 -- make -j3
python3 scripts/run_with_timeout.py 300 -- make check
python3 scripts/run_with_timeout.py 180 -- make install
export PATH="$SRC/local-install/bin:$PATH"
iverilog -V
vvp -V
python3 scripts/run_with_timeout.py 1200 -- ./ci/run-smoke.sh
status=0
run_step() {
    local label="$1"
    shift
    printf '\n=== %s ===\n' "$label"
    set +e
    "$@"
    local rc=$?
    set -e
    printf '%s\t%s\n' "$label" "$rc" | tee -a "$RESULTS/steps.tsv"
    if [ "$rc" -ne 0 ]; then status=1; fi
    return 0
}
cd "$SRC/ivtest"
run_step T0-legacy-focused python3 ../scripts/run_with_timeout.py 400 -- perl ./vvp_reg.pl regress-parent-child-class-joint-legacy.list
printf 'sv_constraint_parent_child_class_joint vvp_tests/sv_constraint_parent_child_class_joint.json\n' > "$RESULTS/t0-2017.list"
run_step T0-json-2017 python3 ../scripts/run_with_timeout.py 180 -- python3 ./vvp_reg.py "$RESULTS/t0-2017.list"
printf 'sv_constraint_parent_child_class_joint_2023 vvp_tests/sv_constraint_parent_child_class_joint_2023.json\n' > "$RESULTS/t0-2023.list"
run_step T0-json-2023 python3 ../scripts/run_with_timeout.py 180 -- python3 ./vvp_reg.py "$RESULTS/t0-2023.list"
pattern='^(sv_constraint_cross_object_solve_before(_2023)?|sv_constraint_handle_rollback(_2023)?|sv_constraint_parent_child_class_joint(_2023)?|sv_randomize_global_components(_fail)?(_2023)?|sv_randomize_global_randc(_2023)?)$'
awk -v pattern="$pattern" '$1 ~ pattern' regress-sv.list > "$RESULTS/t1-legacy.list"
awk -v pattern="$pattern" '$1 ~ pattern' regress-vvp.list > "$RESULTS/t1-json.list"
[ "$(wc -l < "$RESULTS/t1-legacy.list")" -eq 12 ]
[ "$(wc -l < "$RESULTS/t1-json.list")" -eq 12 ]
run_step T1-legacy-constraint-neighbors python3 ../scripts/run_with_timeout.py 1200 -- perl ./vvp_reg.pl "$RESULTS/t1-legacy.list"
while read -r name json; do
    printf '%s %s\n' "$name" "$json" > "$RESULTS/one-json.list"
    run_step "T1-json-$name" python3 ../scripts/run_with_timeout.py 180 -- python3 ./vvp_reg.py "$RESULTS/one-json.list"
done < "$RESULTS/t1-json.list"
printf 'test_status=%s\n' "$status" > "$RESULTS/test-status.txt"
exit "$status"
