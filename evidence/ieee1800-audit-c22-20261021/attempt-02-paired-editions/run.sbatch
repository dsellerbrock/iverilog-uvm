#!/usr/bin/env bash
#SBATCH --job-name=a3-c22-paired
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
set -euo pipefail
run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c22-20261021-002
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum ivltests/fileline2.v expected.gold p22_14_keywords_2017.sv p22_14_keywords_2023.sv n22_14_unknown_keywords_version.sv n22_14_unpaired_keywords_2023.sv
for edition in 2017 2023; do
  timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/iverilog" "-g$edition" -o "$run_dir/build/fileline2-$edition.vvp" ivltests/fileline2.v >"$run_dir/logs/fileline2-compile-$edition.stdout" 2>"$run_dir/logs/fileline2-compile-$edition.stderr"
  timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/vvp" "$run_dir/build/fileline2-$edition.vvp" >"$run_dir/logs/fileline2-run-$edition.stdout" 2>"$run_dir/logs/fileline2-run-$edition.stderr"
  if diff -u expected.gold "$run_dir/logs/fileline2-run-$edition.stdout"; then echo "fileline2 edition=$edition golden=PASS"; else echo "fileline2 edition=$edition golden=FAIL"; fi
  for case_name in p22_14_keywords_2017 n22_14_unknown_keywords_version n22_14_unpaired_keywords_2023; do
    case "$case_name" in
      p22_14_keywords_2017) top=keywords_2017 ;;
      n22_14_unknown_keywords_version) top=unknown_keywords_version ;;
      n22_14_unpaired_keywords_2023) top=unpaired_keywords_2023 ;;
    esac
    if timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/iverilog" "-g$edition" -s "$top" -o "$run_dir/build/$case_name-$edition.vvp" "$case_name.sv" >"$run_dir/logs/$case_name-$edition.stdout" 2>"$run_dir/logs/$case_name-$edition.stderr"; then rc=0; else rc=$?; fi
    printf '%s edition=%s compile_exit=%s\n' "$case_name" "$edition" "$rc"
    cat "$run_dir/logs/$case_name-$edition.stderr"
  done
done
if timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/iverilog" -g2023 -s keywords_2023 -o "$run_dir/build/p22_14_keywords_2023.vvp" p22_14_keywords_2023.sv >"$run_dir/logs/p22_14_keywords_2023.stdout" 2>"$run_dir/logs/p22_14_keywords_2023.stderr"; then rc=0; else rc=$?; fi
printf 'p22_14_keywords_2023 edition=2023 compile_exit=%s\n' "$rc"
cat "$run_dir/logs/p22_14_keywords_2023.stderr"
