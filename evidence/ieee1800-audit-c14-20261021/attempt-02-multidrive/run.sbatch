#!/usr/bin/env bash
#SBATCH --job-name=a3-c14-c16
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:40:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c14-c16-20261021-attempt-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c14-c16-20261021-attempt-01/logs/slurm-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c14-c16-20261021-attempt-01/logs/slurm-%j.err
set -u
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
mkdir -p results logs
printf 'clause\tcase\tedition\tcompile_rc\trun_rc\n' > results/status.tsv
{
  echo 'Host: DAN-DESKTOP'
  echo 'Icarus 13.0 devel (cc25756d1)'
  echo "Toolchain root: $IVL_ROOT"
  "$IVL_ROOT/bin/iverilog" -V 2>&1 | sed -n '1p'
  "$IVL_ROOT/bin/vvp" -V 2>&1 | sed -n '1p'
  sha256sum "$IVL_ROOT/bin/iverilog" "$IVL_ROOT/bin/vvp"
} > results/toolchain.txt
for group in c14 c16; do
  for src in inputs/"$group"/*.sv; do
    name=$(basename "$src" .sv)
    for edition in 2017 2023; do
      compile_log="logs/$group-$name-g$edition.compile.log"
      run_log="logs/$group-$name-g$edition.run.log"
      out="results/$group-$name-g$edition.vvp"
      flags=(-g"$edition")
      [[ "$group" == c16 ]] && flags+=(-gassertions)
      echo "=== $group/$name -g$edition compile ==="
      timeout --signal=TERM --kill-after=5s 30s "$IVL_ROOT/bin/iverilog" \
        -B "$IVL_ROOT/lib/ivl" "${flags[@]}" -o "$out" "$src" >"$compile_log" 2>&1
      crc=$?
      rrc=NA
      case "$group/$name" in
        c14/d*|c16/s*)
          if [ "$crc" -eq 0 ]; then
            timeout --signal=TERM --kill-after=5s 30s "$IVL_ROOT/bin/vvp" "$out" >"$run_log" 2>&1
            rrc=$?
          fi
          ;;
      esac
      cat "$compile_log"
      if [ -f "$run_log" ]; then cat "$run_log"; fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$group" "$name" "$edition" "$crc" "$rrc" | tee -a results/status.tsv
    done
  done
done
{
  sha256sum "$IVL_ROOT/bin/iverilog" "$IVL_ROOT/bin/vvp"
  find inputs -type f -name '*.sv' -print0 | sort -z | xargs -0 sha256sum
} > results/SHA256SUMS
exit 0
