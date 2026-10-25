#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-shuffle
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/1800-c18r-20261020-03/logs/%x-%j.out

set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/1800-c18r-20261020-03
TOOLCHAIN=/home/dsell/toolchains/iverilog-fb584a25-20261020
SRC="$RUN_DIR/input/p18_14_shuffle_stability.sv"
RESULT="$RUN_DIR/result.txt"
SEED=123456789

printf 'source_head=fb584a251dd4cc91e56a75be662ccd5ee05c64e9\n' > "$RESULT"
printf 'probe_sha256=%s\n' "$(sha256sum "$SRC" | cut -d ' ' -f1)" >> "$RESULT"
printf 'seed=+ntb_random_seed=%s\n' "$SEED" >> "$RESULT"
printf 'iverilog_sha256=%s\n' "$(sha256sum "$TOOLCHAIN/bin/iverilog" | cut -d ' ' -f1)" >> "$RESULT"
printf 'vvp_sha256=%s\n' "$(sha256sum "$TOOLCHAIN/bin/vvp" | cut -d ' ' -f1)" >> "$RESULT"

overall=0
for edition in 2017 2023; do
  for variant in base delay_a; do
    args=()
    if [ "$variant" = delay_a ]; then args=(-DDELAY_A); fi
    set +e
    timeout -s TERM -k 2s 30s "$TOOLCHAIN/bin/iverilog" -g"$edition" -s test \
      "${args[@]}" -o "$RUN_DIR/$variant-$edition.vvp" "$SRC" \
      > "$RUN_DIR/logs/compile-$edition-$variant.stdout" \
      2> "$RUN_DIR/logs/compile-$edition-$variant.stderr"
    compile_rc=$?
    set -e
    printf 'compile_%s_%s_rc=%s\n' "$edition" "$variant" "$compile_rc" >> "$RESULT"
    if [ "$compile_rc" -ne 0 ]; then overall=1; continue; fi

    for repeat in 1 2; do
      set +e
      timeout -s TERM -k 2s 30s "$TOOLCHAIN/bin/vvp" "$RUN_DIR/$variant-$edition.vvp" \
        "+ntb_random_seed=$SEED" \
        > "$RUN_DIR/logs/run-$edition-$variant-$repeat.stdout" \
        2> "$RUN_DIR/logs/run-$edition-$variant-$repeat.stderr"
      run_rc=$?
      set -e
      printf 'run_%s_%s_%s_rc=%s\n' "$edition" "$variant" "$repeat" "$run_rc" >> "$RESULT"
      if [ "$run_rc" -ne 0 ]; then overall=1; fi
      grep -Fxq 'PASS shuffle thread stability' \
        "$RUN_DIR/logs/run-$edition-$variant-$repeat.stdout" || overall=1
      grep -E '^(A|B)=' "$RUN_DIR/logs/run-$edition-$variant-$repeat.stdout" \
        | sort > "$RUN_DIR/logs/streams-$edition-$variant-$repeat.txt" || overall=1
    done
  done

  for variant in base delay_a; do
    if diff -u "$RUN_DIR/logs/streams-$edition-$variant-1.txt" \
              "$RUN_DIR/logs/streams-$edition-$variant-2.txt" \
         > "$RUN_DIR/logs/replay-$edition-$variant.diff"; then
      printf 'replay_%s_%s=PASS\n' "$edition" "$variant" >> "$RESULT"
    else
      printf 'replay_%s_%s=FAIL\n' "$edition" "$variant" >> "$RESULT"
      overall=1
    fi
  done

  if diff -u "$RUN_DIR/logs/streams-$edition-base-1.txt" \
            "$RUN_DIR/logs/streams-$edition-delay_a-1.txt" \
       > "$RUN_DIR/logs/compare-$edition.diff"; then
    printf 'stability_%s=PASS\n' "$edition" >> "$RESULT"
  else
    printf 'stability_%s=FAIL\n' "$edition" >> "$RESULT"
    overall=1
  fi
done

if [ "$overall" -eq 0 ]; then
  printf 'probe=PASS\n' >> "$RESULT"
else
  printf 'probe=FAIL\n' >> "$RESULT"
  exit 1
fi
