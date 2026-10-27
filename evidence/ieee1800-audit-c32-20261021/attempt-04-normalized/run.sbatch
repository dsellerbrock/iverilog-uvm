#!/usr/bin/env bash
#SBATCH --job-name=a3-c32-normalized
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00

set -uo pipefail
run_dir=/home/dsell/slurm-runs/iverilog-uvm/A3/c32-remaining-20261021-02
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'host=%s\n' "$(hostname)"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum ./*.sv ./*.sdf expected/*.txt
sha256sum "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"

harness_status=0
feature_gaps=0
run_case() {
  local test="$1" edition="$2" mode="$3" expected="$4"
  shift 4
  local stem="$test-$edition-$mode"
  local image="$run_dir/build/$stem.vvp"
  local stdout="$run_dir/logs/$stem.run.stdout"
  local stderr="$run_dir/logs/$stem.run.stderr"

  if timeout --signal=TERM --kill-after=5s 30s "$iverilog" -B "$base" "-g$edition" -gspecify "$@" -o "$image" "$test.sv" >"$run_dir/logs/$stem.compile.stdout" 2>"$run_dir/logs/$stem.compile.stderr"; then
    printf 'compile_ok test=%s edition=%s mode=%s\n' "$test" "$edition" "$mode"
  else
    rc=$?
    printf 'compile_failed test=%s edition=%s mode=%s exit=%s\n' "$test" "$edition" "$mode" "$rc"
    harness_status=1
    return 0
  fi

  if timeout --signal=TERM --kill-after=5s 30s "$vvp" "$image" >"$stdout" 2>"$stderr"; then
    printf 'run_ok test=%s edition=%s mode=%s\n' "$test" "$edition" "$mode"
    # Compare only post-stimulus transitions; ignore initialization and $finish chatter.
    awk '$1 == "Y" && $2 >= 10' "$stdout" >"$run_dir/logs/$stem.y"
    if [ -n "$expected" ]; then
      if diff -u "$expected" "$run_dir/logs/$stem.y"; then
        printf 'feature_expectation_match test=%s edition=%s mode=%s\n' "$test" "$edition" "$mode"
      else
        printf 'FEATURE_EXPECTATION_MISMATCH test=%s edition=%s mode=%s\n' "$test" "$edition" "$mode"
        feature_gaps=$((feature_gaps + 1))
      fi
    fi
  else
    rc=$?
    printf 'run_failed test=%s edition=%s mode=%s exit=%s\n' "$test" "$edition" "$mode" "$rc"
    harness_status=1
  fi
}

for edition in 2017 2023; do
  run_case p32_tchk "$edition" annotated ""
  run_case p32_tchk "$edition" control "" -DNO_SDF
  annotated="p32_tchk-$edition-annotated"
  control="p32_tchk-$edition-control"
  annotated_count=$(cat "$run_dir/logs/$annotated.run.stdout" "$run_dir/logs/$annotated.run.stderr" 2>/dev/null | grep -c 'Timing violation:' || true)
  control_count=$(cat "$run_dir/logs/$control.run.stdout" "$run_dir/logs/$control.run.stderr" 2>/dev/null | grep -c 'Timing violation:' || true)
  printf 'setup_violations edition=%s annotated=%s control=%s\n' "$edition" "$annotated_count" "$control_count"
  if [ "$annotated_count" -ne 1 ] || [ "$control_count" -ne 0 ]; then
    printf 'FEATURE_EXPECTATION_MISMATCH feature=timingcheck edition=%s\n' "$edition"
    feature_gaps=$((feature_gaps + 1))
  fi

  for mode in MINIMUM TYPICAL MAXIMUM; do
    case "$mode" in
      MINIMUM) expected=expected/mtm-minimum.txt ;;
      TYPICAL) expected=expected/mtm-typical.txt ;;
      MAXIMUM) expected=expected/mtm-maximum.txt ;;
    esac
    run_case p32_mtm "$edition" "$mode" "$expected" "-DMTM_$mode"
  done

  run_case p32_scale "$edition" from-typical expected/scale.txt
  run_case p32_ic "$edition" interconnect expected/interconnect.txt -ginterconnect
done

for log in "$run_dir"/logs/*; do
  [ -f "$log" ] || continue
  count=$(grep -c 'SDF ERROR' "$log" || true)
  printf 'sdf_error_count=%s file=%s\n' "$count" "$(basename "$log")"
  if [ "$count" -gt 0 ]; then harness_status=1; fi
done

printf 'FEATURE_GAPS=%s\nHARNESS_STATUS=%s\n' "$feature_gaps" "$harness_status"
exit "$harness_status"
