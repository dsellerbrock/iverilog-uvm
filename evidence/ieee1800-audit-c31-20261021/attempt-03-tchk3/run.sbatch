#!/usr/bin/env bash
#SBATCH --job-name=a3-c31-tchk3
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c31-tchk3-20261021-a1/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/A3/c31-tchk3-20261021-a1
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
status=0

mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"
printf 'host=%s\n' "$(hostname)"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
printf 'toolchain=%s\n' "$toolchain"
sha256sum ./*.sv "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"

for edition in 2017 2023; do
  output="$run_dir/build/p31-tchk3-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" \
    "-g$edition" -gspecify -o "$output" p31_tchk3.sv \
    >"$run_dir/logs/p31-tchk3-$edition.compile.stdout" \
    2>"$run_dir/logs/p31-tchk3-$edition.compile.stderr"; then
    printf 'tchk3 edition=%s compile_exit=0\n' "$edition"
    if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" \
      >"$run_dir/logs/p31-tchk3-$edition.run.stdout" \
      2>"$run_dir/logs/p31-tchk3-$edition.run.stderr"; then
      printf 'tchk3 edition=%s run_exit=0\n' "$edition"
      cat "$run_dir/logs/p31-tchk3-$edition.run.stdout"
      cat "$run_dir/logs/p31-tchk3-$edition.run.stderr" >&2
    else
      rc=$?
      printf 'tchk3 edition=%s run_exit=%s\n' "$edition" "$rc"
      status=1
    fi
  else
    rc=$?
    printf 'tchk3 edition=%s compile_exit=%s\n' "$edition" "$rc"
    cat "$run_dir/logs/p31-tchk3-$edition.compile.stderr" >&2
    status=1
  fi

  neg_output="$run_dir/build/p31-neg-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" \
    "-g$edition" -gspecify -o "$neg_output" p31_neg.sv \
    >"$run_dir/logs/p31-neg-$edition.compile.stdout" \
    2>"$run_dir/logs/p31-neg-$edition.compile.stderr"; then
    printf 'negative edition=%s compile_exit=0 no_extra_option\n' "$edition"
    if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$neg_output" \
      >"$run_dir/logs/p31-neg-$edition.run.stdout" \
      2>"$run_dir/logs/p31-neg-$edition.run.stderr"; then
      printf 'negative edition=%s run_exit=0 no_extra_option\n' "$edition"
      cat "$run_dir/logs/p31-neg-$edition.run.stdout"
      cat "$run_dir/logs/p31-neg-$edition.run.stderr" >&2
    else
      rc=$?
      printf 'negative edition=%s run_exit=%s no_extra_option\n' "$edition" "$rc"
    fi
  else
    rc=$?
    printf 'negative edition=%s compile_exit=%s no_extra_option\n' "$edition" "$rc"
    cat "$run_dir/logs/p31-neg-$edition.compile.stderr" >&2
  fi
done

printf 'option_probe=iverilog -g2023 -gspecify -gneg_tchk\n'
if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" \
  -g2023 -gspecify -gneg_tchk -o "$run_dir/build/p31-neg-option.vvp" p31_neg.sv \
  >"$run_dir/logs/p31-neg-option.compile.stdout" \
  2>"$run_dir/logs/p31-neg-option.compile.stderr"; then
  printf 'negative_option_candidate=accepted\n'
else
  rc=$?
  printf 'negative_option_candidate=compile_exit_%s\n' "$rc"
  cat "$run_dir/logs/p31-neg-option.compile.stderr" >&2
fi

"$iverilog" -h >"$run_dir/logs/iverilog-help.txt" 2>&1 || true
"$vvp" -h >"$run_dir/logs/vvp-help.txt" 2>&1 || true
man iverilog 2>/dev/null | col -b >"$run_dir/logs/iverilog-man.txt" || true
grep -in -C2 -E 'negative timing|negative.*check|neg_tchk|specify' "$run_dir/logs/iverilog-man.txt" \
  >"$run_dir/logs/iverilog-man-timing-options.txt" || true
exit "$status"
