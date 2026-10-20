#!/usr/bin/env bash
#SBATCH --job-name=a5-wp13-inc2
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-inclusive-parse-job3383-r2-20261020/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-inclusive-parse-job3383-r2-20261020/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-inclusive-parse-job3383-r2-20261020
INPUT=$ROOT/input
OUTPUT=$ROOT/results
BASE=fb584a251dd4cc91e56a75be662ccd5ee05c64e9

mkdir -p "$OUTPUT"
printf 'pinned_base=%s\nprofile_job=3383\nprofile_source=cc25756d187314742d347267c2a513b3e640a7fb\n' \
    "$BASE" > "$OUTPUT/provenance.txt"
sha256sum "$INPUT"/*.py "$INPUT"/raw/*.data.gz > "$OUTPUT/input-sha256.txt"

run_one() {
    name=$1
    timeout --signal=TERM --kill-after=20s 600s \
        python3 "$INPUT/inclusive_bplane.py" "$INPUT/raw/$name.data.gz" \
        > "$OUTPUT/$name-inclusive.json"
}

run_one smoke_test_dma_aes_gcm_short_1_dword
run_one smoke_test_sha256
run_one cptra_ss_test_rom
touch "$OUTPUT/SUCCESS"
