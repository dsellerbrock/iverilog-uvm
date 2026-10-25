#!/usr/bin/env bash
#SBATCH --job-name=a3-c04-regions2
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

cat > expected.txt <<'EOF'
R1 act b=0
R2 inact b=0
R4 react b=1
R5 post b=1 c=2 d=0
EOF

status=0
for edition in 2017 2023; do
  if timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s p04_regions -s p04_prog -o "build/p04_regions-$edition.vvp" tests/p04_regions.sv >"results/p04_regions-$edition.compile.log" 2>&1; then
    echo "COMPILE_OK p04_regions -g$edition"
  else
    rc=$?
    echo "COMPILE_FAILED p04_regions -g$edition exit=$rc"
    cat "results/p04_regions-$edition.compile.log"
    status=1
    continue
  fi
  if timeout --signal=TERM --kill-after=5s 30s "$VVP" "build/p04_regions-$edition.vvp" >"results/p04_regions-$edition.out" 2>"results/p04_regions-$edition.run.log"; then
    echo "RUN_OK p04_regions -g$edition"
    cat "results/p04_regions-$edition.out"
    if diff -u expected.txt "results/p04_regions-$edition.out"; then
      echo "EXPECTED_OUTPUT_MATCH -g$edition"
    else
      echo "EXPECTED_OUTPUT_MISMATCH -g$edition"
      status=1
    fi
  else
    rc=$?
    echo "RUN_FAILED p04_regions -g$edition exit=$rc"
    cat "results/p04_regions-$edition.run.log"
    status=1
  fi
done

echo "FINAL_STATUS=$status"
exit "$status"
