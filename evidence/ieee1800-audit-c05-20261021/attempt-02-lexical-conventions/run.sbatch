#!/usr/bin/env bash
#SBATCH --job-name=a3-c05-lex
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
  for name in p05_lex p05_lex23; do
    if timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s "$name" -o "build/$name-$edition.vvp" "tests/$name.sv" >"results/$name-$edition.compile.log" 2>&1; then
      echo "COMPILE_OK $name -g$edition"
      if timeout --signal=TERM --kill-after=5s 30s "$VVP" "build/$name-$edition.vvp" >"results/$name-$edition.out" 2>"results/$name-$edition.run.log"; then
        echo "RUN_OK $name -g$edition"
        cat "results/$name-$edition.out"
      else
        rc=$?
        echo "RUN_EXIT $name -g$edition exit=$rc"
        cat "results/$name-$edition.run.log"
        status=1
      fi
    else
      rc=$?
      echo "COMPILE_REJECTED $name -g$edition exit=$rc"
      cat "results/$name-$edition.compile.log"
      status=1
    fi
  done

  set +e
  timeout --signal=TERM --kill-after=5s 30s "$IVL" "-g$edition" -s n05_nested_comment -o "build/n05_nested_comment-$edition.vvp" tests/n05_nested_comment.sv >"results/n05_nested_comment-$edition.log" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "NESTED_COMMENT_ACCEPTED -g$edition"
    status=1
  elif [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    echo "NESTED_COMMENT_TIMEOUT -g$edition exit=$rc"
    status=1
  else
    echo "NESTED_COMMENT_REJECTED -g$edition exit=$rc"
    cat "results/n05_nested_comment-$edition.log"
  fi
done

echo "FINAL_STATUS=$status"
exit "$status"
