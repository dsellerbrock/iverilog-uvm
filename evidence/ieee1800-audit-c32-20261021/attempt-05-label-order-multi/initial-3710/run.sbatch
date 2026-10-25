#!/usr/bin/env bash
#SBATCH --job-name=a3-c32-a05
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c32-label-order-multi-20261021-01/logs/%x-%j.out

set -uo pipefail
run_dir=/home/dsell/slurm-runs/iverilog-uvm/A3/c32-label-order-multi-20261021-01
toolchain=/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'host=%s\ntoolchain=%s\n' "$(hostname)" "$toolchain"
"$iverilog" -V | head -2
sha256sum ./*.sv ./*.sdf "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"

harness_status=0
feature_gaps=0
run_case() {
  local label="$1" test="$2" top="$3" edition="$4" expected="$5"
  shift 5
  local stem="$label-$edition"
  local image="$run_dir/build/$stem.vvp"
  local stdout="$run_dir/logs/$stem.run.stdout"
  local stderr="$run_dir/logs/$stem.run.stderr"

  if timeout --signal=TERM --kill-after=5s 30s "$iverilog" -B "$base" "-g$edition" -gspecify -s "$top" "$@" -o "$image" "$test.sv" >"$run_dir/logs/$stem.compile.stdout" 2>"$run_dir/logs/$stem.compile.stderr"; then
    printf 'compile_ok case=%s edition=%s\n' "$label" "$edition"
  else
    rc=$?
    printf 'compile_failed case=%s edition=%s exit=%s\n' "$label" "$edition" "$rc"
    harness_status=1
    return
  fi

  if timeout --signal=TERM --kill-after=5s 30s "$vvp" "$image" >"$stdout" 2>"$stderr"; then
    printf 'run_ok case=%s edition=%s\n' "$label" "$edition"
    grep -E '^[RF][1-6] ' "$stdout" >"$run_dir/logs/$stem.normalized" || true
    if diff -u "$run_dir/expected/$expected" "$run_dir/logs/$stem.normalized"; then
      printf 'expectation_match case=%s edition=%s\n' "$label" "$edition"
    else
      printf 'FEATURE_EXPECTATION_MISMATCH case=%s edition=%s\n' "$label" "$edition"
      feature_gaps=$((feature_gaps + 1))
    fi
  else
    rc=$?
    printf 'run_failed case=%s edition=%s exit=%s\n' "$label" "$edition" "$rc"
    harness_status=1
  fi
}

for edition in 2017 2023; do
  run_case label-ok p32_label p32_label "$edition" p32_label.txt -DLABEL_OK
  run_case label-mixed p32_label p32_label "$edition" p32_label_mixed.txt -DLABEL_MIXED
  run_case label-control p32_label p32_label "$edition" p32_label_ctl.txt
  run_case order-ai p32_order p32_order "$edition" p32_order_ai.txt -DORDER_AI
  run_case order-ia p32_order p32_order "$edition" p32_order_ia.txt
  run_case multi p32_multi p32_multi "$edition" p32_multi.txt
done

for log in "$run_dir"/logs/*; do
  [ -f "$log" ] || continue
  count=$(grep -c 'SDF ERROR' "$log" || true)
  if [[ "$log" == *label-ok-*.run.stdout || "$log" == *label-mixed-*.run.stdout ]]; then
    printf 'LABEL_PARSE_ERROR_COUNT=%s file=%s\n' "$count" "$(basename "$log")"
  elif [ "$count" -gt 0 ]; then
    printf 'UNEXPECTED_SDF_ERROR_COUNT=%s file=%s\n' "$count" "$(basename "$log")"
    harness_status=1
  fi
done
grep -h 'SDF WARNING' "$run_dir"/logs/* 2>/dev/null || true
printf 'FEATURE_GAPS=%s\nHARNESS_STATUS=%s\n' "$feature_gaps" "$harness_status"
exit "$harness_status"
