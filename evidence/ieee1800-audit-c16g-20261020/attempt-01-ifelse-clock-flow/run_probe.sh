#!/usr/bin/env bash
#SBATCH --job-name=a3-c16g-ifelse
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00

set -euo pipefail
run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c16g-20261020-002
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
source_file="$run_dir/p16_13_4_ifelse_clock_flow.sv"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' /home/dsell/toolchains/iverilog-fb584a25-20261020/BUILD-INFO)"
printf 'edition_flag=-g2012 (the toolchain does not implement -g2017/-g2023)\n'
sha256sum "$source_file"
mkdir -p "$run_dir/build"
set +e
timeout --signal=TERM --kill-after=2s 30s \
  "$toolchain/bin/iverilog" -g2012 -s p16_13_4_ifelse_clock_flow \
  -o "$run_dir/build/p16_13_4_ifelse_clock_flow.vvp" "$source_file" \
  >"$run_dir/build/compile.log" 2>&1
compile_rc=$?
cat "$run_dir/build/compile.log"
sim_rc=127
if [[ -f "$run_dir/build/p16_13_4_ifelse_clock_flow.vvp" ]]; then
  timeout --signal=TERM --kill-after=2s 30s \
    "$toolchain/bin/vvp" "$run_dir/build/p16_13_4_ifelse_clock_flow.vvp" \
    >"$run_dir/build/sim.log" 2>&1
  sim_rc=$?
  cat "$run_dir/build/sim.log"
fi
printf 'compile_rc=%s\nsimulation_rc=%s\n' "$compile_rc" "$sim_rc"
if grep -Eq 'sorry: .*supported only with a boolean branch|assertion is dropped|uses a form that supports only one instantiation' "$run_dir/build/compile.log"; then
  echo 'PROBE_RESULT=STANDARD_VALID_IF_ELSE_PROPERTY_DROPPED'
  exit 2
fi
if [[ "$compile_rc" -ne 0 || "$sim_rc" -ne 0 ]] || \
   ! grep -Fq 'PASSED: IEEE 1800 16.13.4(g)' "$run_dir/build/sim.log"; then
  echo 'PROBE_RESULT=FAILED'
  exit 3
fi
echo 'PROBE_RESULT=PASS'
