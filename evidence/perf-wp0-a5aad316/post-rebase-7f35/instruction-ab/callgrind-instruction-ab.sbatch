#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp0-icount-7f35-r1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-1174ea06-7f35-20261014-r1/input
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-1174ea06-7f35-20261014-r1/logs/%x-%j.out

set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-1174ea06-7f35-20261014-r1
BUILD_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-1174ea06-7f35-20261014-r1
OLD_TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-f9f8-20261014-r1/tools
TOOLS="$RUN_DIR/tools/root"
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/results" "$RUN_DIR/tools/debs" "$RUN_DIR/tools/root" "$RUN_DIR/input" "$RUN_DIR/tmp"
cd "$RUN_DIR"

cp "$OLD_TOOLS/debs/valgrind_1%3a3.26.0-0ubuntu1_amd64.deb" \
  "$OLD_TOOLS/debs/libc6-dbg_2.43-2ubuntu2.4_amd64.deb" "$RUN_DIR/tools/debs/"
cat > "$RUN_DIR/tools/packages.SHA256SUMS" <<'EOF'
523851368691971a1553c7dacc7cf9e0cd54a78ca70bbdd735d932f16e089ae3  libc6-dbg_2.43-2ubuntu2.4_amd64.deb
70b10c31307700a388262baa9cff7a3b27814a9716b6f19e8f748a56bcbfa442  valgrind_1%3a3.26.0-0ubuntu1_amd64.deb
EOF
(cd "$RUN_DIR/tools/debs" && sha256sum -c "$RUN_DIR/tools/packages.SHA256SUMS")
dpkg-deb -x "$RUN_DIR/tools/debs/valgrind_1%3a3.26.0-0ubuntu1_amd64.deb" "$TOOLS"
dpkg-deb -x "$RUN_DIR/tools/debs/libc6-dbg_2.43-2ubuntu2.4_amd64.deb" "$TOOLS"

VALGRIND="$TOOLS/usr/bin/valgrind"
VALGRIND_LIB="$TOOLS/usr/libexec/valgrind"
export VALGRIND_LIB
export PATH="$BUILD_DIR/install-off/bin:$PATH"
export IVERILOG="$BUILD_DIR/install-off/bin/iverilog"
export LC_ALL=C
export TMPDIR="$RUN_DIR/tmp"
"$VALGRIND" --version > "$RUN_DIR/tools/valgrind-version.txt"
printf 'campaign_pinned_base=%s\nmeasurement_base=%s\ncandidate_commit=%s\n' \
  'f9f8e0a79f230f38da6cbb4445994ad1075ad531' \
  '7f35ca38c86723ab40e6ebfe9fd77259827e23f9' \
  '1174ea06ac5e3a926b1fa1c1bd3449a396507272' > "$RUN_DIR/source-manifest.txt"
printf 'uvm_core_submodule=%s\nfull_gates_build_job=1150\ninstruction_cpu_request=1\n' \
  '78c06547a2a0a29b3dc9dcafae62b75b2ff61544' >> "$RUN_DIR/source-manifest.txt"
printf 'candidate_archive_sha256=%s\nuvm_core_archive_sha256=%s\n' \
  '18238576955ec2bc11707beff18078cca4b850e07e3fdfe4aa275157d759ab1f' \
  '47edabcda41a463532346d45b5479a7e3101202e620af762fc203467526e3845' \
  >> "$RUN_DIR/source-manifest.txt"

export CAMPAIGN_PINNED_BASE=f9f8e0a79f230f38da6cbb4445994ad1075ad531
export MEASUREMENT_BASE=7f35ca38c86723ab40e6ebfe9fd77259827e23f9
export CANDIDATE_COMMIT=1174ea06ac5e3a926b1fa1c1bd3449a396507272
bash "$RUN_DIR/input/callgrind-instruction-ab.sh" \
  "$BUILD_DIR/baseline-install/bin/vvp" \
  "$BUILD_DIR/install-off/bin/vvp" \
  "$IVERILOG" "$VALGRIND" "$VALGRIND_LIB" \
  "$BUILD_DIR/source-off/benchmarks/sim-hotspots/behav.sv" "$RUN_DIR/results"

sha256sum "$RUN_DIR/results/reference.callgrind" "$RUN_DIR/results/candidate.callgrind" \
  > "$RUN_DIR/results/profiles.SHA256SUMS"
gzip -n "$RUN_DIR/results/reference.callgrind" "$RUN_DIR/results/candidate.callgrind"
find "$RUN_DIR/results" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "$RUN_DIR/logs.sha256"
sha256sum "$RUN_DIR/source-manifest.txt" "$RUN_DIR/tools/packages.SHA256SUMS" \
  "$RUN_DIR/tools/valgrind-version.txt" >> "$RUN_DIR/logs.sha256"
