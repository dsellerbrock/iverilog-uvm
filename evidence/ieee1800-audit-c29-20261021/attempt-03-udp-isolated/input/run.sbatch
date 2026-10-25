#!/usr/bin/env bash
#SBATCH --job-name=a3-c29-udp3
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
TOOLCHAIN=/home/dsell/toolchains/iverilog-fb584a25-20261020
IVL="$TOOLCHAIN/bin/iverilog"
VVP="$TOOLCHAIN/bin/vvp"
mkdir -p build results
echo "HOST=$(hostname)"
echo "TOOLCHAIN_SOURCE_COMMIT=fb584a251dd4cc91e56a75be662ccd5ee05c64e9"
sha256sum "$IVL" "$VVP"

status=0
run_positive() {
  local label=$1 source=$2 top=$3 expected=$4
  local edition rc
  for edition in 2017 2023; do
    if timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s "$top" -o "build/$label-$edition.vvp" "$source" >"results/$label-$edition.compile.log" 2>&1; then
      echo "COMPILED $label -g$edition"
      if timeout --signal=TERM --kill-after=5s 30s "$VVP" "build/$label-$edition.vvp" >"results/$label-$edition.out" 2>"results/$label-$edition.run.log"; then
        cat "results/$label-$edition.out"
        if diff -u "$expected" "results/$label-$edition.out"; then
          echo "OUTPUT_MATCH $label -g$edition"
        else
          echo "OBSERVED_OUTPUT_MISMATCH $label -g$edition"
        fi
      else
        rc=$?
        cat "results/$label-$edition.run.log"
        echo "OBSERVED_RUN_EXIT $label -g$edition exit=$rc"
        if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then status=1; fi
      fi
    else
      rc=$?
      cat "results/$label-$edition.compile.log"
      echo "OBSERVED_COMPILE_REJECTION $label -g$edition exit=$rc"
      if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then status=1; fi
    fi
  done
}

run_positive p29_more tests/p29_more.sv p29_more expected-more.txt
run_positive p29_instance_array tests/p29_instance_array.sv p29_instance_array expected-array.txt

for edition in 2017 2023; do
  set +e
  timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s n29_delay3 -o "build/n29_delay3-$edition.vvp" tests/n29_delay3.sv >"results/n29_delay3-$edition.log" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "OBSERVED_THREE_DELAY_ACCEPTED -g$edition"
  elif [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    echo "THREE_DELAY_COMPILE_TIMEOUT -g$edition exit=$rc"
    status=1
  else
    echo "THREE_DELAY_REJECTED -g$edition exit=$rc"
    cat "results/n29_delay3-$edition.log"
  fi
done

exit "$status"
