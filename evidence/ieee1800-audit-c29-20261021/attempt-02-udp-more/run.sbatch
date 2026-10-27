#!/usr/bin/env bash
#SBATCH --job-name=a3-c29-udp2
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
for edition in 2017 2023; do
  if ! timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s p29_more -o "build/p29_more-$edition.vvp" tests/p29_more.sv >"results/p29_more-$edition.compile.log" 2>&1; then
    cat "results/p29_more-$edition.compile.log"
    echo "FAIL p29_more compile -g$edition"
    status=1
    continue
  fi
  if ! timeout --signal=TERM --kill-after=5s 30s "$VVP" "build/p29_more-$edition.vvp" >"results/p29_more-$edition.out" 2>"results/p29_more-$edition.run.log"; then
    cat "results/p29_more-$edition.run.log"
    echo "FAIL p29_more run -g$edition"
    status=1
    continue
  fi
  echo "--- p29_more -g$edition ---"
  cat "results/p29_more-$edition.out"
  if ! diff -u expected.txt "results/p29_more-$edition.out"; then
    echo "FAIL p29_more output -g$edition"
    status=1
  else
    echo "PASS p29_more -g$edition"
  fi

  set +e
  timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s n29_delay3 -o "build/n29_delay3-$edition.vvp" tests/n29_delay3.sv >"results/n29_delay3-$edition.log" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL third delay was accepted -g$edition"
    status=1
  elif [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    echo "FAIL third-delay compile timed out -g$edition (exit $rc)"
    status=1
  else
    echo "EXPECTED_REJECTION n29_delay3 -g$edition (exit $rc)"
    cat "results/n29_delay3-$edition.log"
  fi
done

exit "$status"
