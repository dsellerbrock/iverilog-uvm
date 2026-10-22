#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c16-9-3-r3
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
set -euo pipefail
run_dir=${SLURM_SUBMIT_DIR:?}
toolchain=/home/dsell/toolchains/iverilog-a3-batch-6604c23e-f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd-53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
printf 'source_sha=6604c23e197980b69a5b6b69864ff8ef8d05eba3\n'
printf 'iverilog_sha256=f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd\n'
printf 'vvp_sha256=53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b\n'
sha256sum "$run_dir"/input/*
"$iverilog" -B "$toolchain/lib/ivl" -V > "$run_dir/results/iverilog-version.txt" 2>&1
run_positive() {
  local name="$1" top="$2" edition="$3" expected="$4"
  local stem="$run_dir/results/$name-$edition" source="$run_dir/input/$name.v"
  [[ -f "$run_dir/input/$name.sv" ]] && source="$run_dir/input/$name.sv"
  echo "=== $name -g$edition ==="
  timeout --signal=TERM --kill-after=5s 120s "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -gassertions -s "$top" -o "$stem.vvp" "$source" > "$stem.compile.log" 2>&1 || { echo "GAP: compile failed $name -g$edition"; cat "$stem.compile.log"; return 0; }
  timeout --signal=TERM --kill-after=5s 120s "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1 || { echo "GAP: runtime exit for $name -g$edition"; cat "$stem.run.log"; return 0; }
  if grep -Eq 'FAILED|FAIL:' "$stem.run.log" || ! grep -Fq "$expected" "$stem.run.log"; then
    echo "GAP: wrong runtime verdict for $name -g$edition"; cat "$stem.run.log"
  else
    echo "PASS: $name -g$edition"; cat "$stem.run.log"
  fi
}
for edition in 2017 2023; do
  run_positive sv_sampled_value_procedural main "$edition" PASSED
  run_positive sv_sampled_value_default_clocking main "$edition" PASSED
  run_positive sv_sampled_value_explicit_clock main "$edition" PASSED
  run_positive sv_sampled_value_preponed_writer_first main "$edition" PASSED
  run_positive sv_assert_multiclock_sampled_values main "$edition" PASSED
  run_positive sampled_preponed sampled_preponed "$edition" 'sampled: good=7 bad=0'
  for name in sv_sampled_value_clocking_input_unsupported n16_09_03_missing_clock; do
    stem="$run_dir/results/$name-$edition"
    source="$run_dir/input/$name.v"
    [[ -f "$run_dir/input/$name.sv" ]] && source="$run_dir/input/$name.sv"
    echo "=== diagnostic $name -g$edition ==="
    set +e
    timeout --signal=TERM --kill-after=5s 120s "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -gassertions -o "$stem.vvp" "$source" > "$stem.compile.log" 2>&1
    rc=$?
    set -e
    echo "compile_exit=$rc" | tee "$stem.status"
    cat "$stem.compile.log"
    if [[ $rc -eq 0 ]]; then
      set +e
      timeout --signal=TERM --kill-after=5s 120s "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1
      rr=$?
      set -e
      echo "run_exit=$rr" | tee -a "$stem.status"
      cat "$stem.run.log"
    fi
  done
done
