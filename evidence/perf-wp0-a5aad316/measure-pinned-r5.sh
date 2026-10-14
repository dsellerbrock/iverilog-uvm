#!/usr/bin/env bash
# Measure the WP0 candidate against its pinned f9f8e0a reference.
#SBATCH --job-name=a5-wp0-measure-f9f8-r5
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=01:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-measure-a5aad316-f9f8-20261014-r5/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-measure-a5aad316-f9f8-20261014-r5/logs/%x-%j.err
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-measure-a5aad316-f9f8-20261014-r5
REF_PREFIX=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-a5aad316-f9f8-20261014-r2/baseline-install
CAND_PREFIX=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-a5aad316-f9f8-20261014-r2/install-off
CAND_SRC="$RUN/source"
ARCHIVES="$RUN/archives"
TMPDIR=/dev/shm/a5-wp0-measure-f9f8-r5
REF_WRAPPER="$RUN/wrappers/reference-vvp"
CAND_WRAPPER="$RUN/wrappers/candidate-vvp"
mkdir -p "$RUN/logs" "$RUN/results" "$RUN/wrappers" "$CAND_SRC" "$CAND_SRC/uvm-core" "$TMPDIR"
export TMPDIR
cd "$RUN"
(cd "$ARCHIVES" && sha256sum -c SHA256SUMS)
printf 'base_commit=%s\ncandidate_commit=%s\n' \
  'f9f8e0a79f230f38da6cbb4445994ad1075ad531' \
  'a5aad31659540d6a4c67bbaeffbeaa484b31f442' > "$RUN/source-manifest.txt"
printf 'uvm_core_submodule=%s\n' \
  '78c06547a2a0a29b3dc9dcafae62b75b2ff61544' >> "$RUN/source-manifest.txt"
printf 'reference_install=%s\ncandidate_install=%s\n' "$REF_PREFIX" "$CAND_PREFIX" >> "$RUN/source-manifest.txt"
printf 'reference_build_job=1048\ncandidate_build_job=1048\nuvm_correctness_job=1052\nmeasurement_cpu_request=1\n' >> "$RUN/source-manifest.txt"
printf 'measurement_attempt=5\nprevious_measurement_job=1057\nfixed_random_seed=73014\ntemporary_output_root=%s\n' "$TMPDIR" >> "$RUN/source-manifest.txt"
printf 'candidate_archive_sha256=%s\nuvm_core_archive_sha256=%s\n' \
  'a9115852b201066c951a2fdfa6a91c79a25aa72c3caf8e6b265aded7bce9f53d' \
  '49be835aa19cff7ba99583b1801e98d5fe7405914bbd5f91a26b8431b88540ab' \
  >> "$RUN/source-manifest.txt"

run_stage() {
  local name="$1" runs="$2" rc=0
  set +e
  bash "$CAND_SRC/benchmarks/sim-hotspots/run.sh" --json \
    "$REF_WRAPPER" "$CAND_WRAPPER" "$runs" \
    > "$RUN/results/$name.json" 2> "$RUN/logs/$name.stderr"
  rc=$?
  set -e
  printf 'exit_code=%s\n' "$rc" > "$RUN/logs/$name.status"
  if [[ "$rc" -ne 0 ]]; then
    printf '%s exited %s\n' "$name" "$rc" | tee -a "$RUN/gate-summary.txt"
    exit "$rc"
  fi
  python3 "$RUN/validate-measurement.py" "$RUN/results/$name.json" "$name" \
    > "$RUN/results/$name.gate.txt"
  cat "$RUN/results/$name.gate.txt" >> "$RUN/gate-summary.txt"
}

test -x "$REF_PREFIX/bin/vvp"
test -x "$REF_PREFIX/bin/iverilog"
test -x "$CAND_PREFIX/bin/vvp"
test -x "$CAND_PREFIX/bin/iverilog"
test -x "$CAND_PREFIX/bin/iverilog-vpi"
test -f "$CAND_PREFIX/lib/ivl/uvm_dpi.vpi"
{
  printf 'host=%s\ndate_utc=%s\nkernel=%s\n' "$(hostname)" "$(date -u +%FT%TZ)" "$(uname -a)"
  gcc --version
  "$REF_PREFIX/bin/iverilog" -V
  "$REF_PREFIX/bin/vvp" -V
  "$CAND_PREFIX/bin/iverilog" -V
  "$CAND_PREFIX/bin/vvp" -V
  perf --version
  ldd "$REF_PREFIX/bin/vvp"
  ldd "$CAND_PREFIX/bin/vvp"
} > "$RUN/logs/tool-version.log" 2>&1
sha256sum "$REF_PREFIX/bin/vvp" "$REF_PREFIX/bin/iverilog" \
  "$CAND_PREFIX/bin/vvp" "$CAND_PREFIX/bin/iverilog" \
  "$CAND_PREFIX/bin/iverilog-vpi" "$CAND_PREFIX/lib/ivl/uvm_dpi.vpi" \
  > "$RUN/binary.sha256"
printf '#!/usr/bin/env bash\nexec "%s" "$@" +ntb_random_seed=73014\n' \
  "$REF_PREFIX/bin/vvp" > "$REF_WRAPPER"
printf '#!/usr/bin/env bash\nexec "%s" "$@" +ntb_random_seed=73014\n' \
  "$CAND_PREFIX/bin/vvp" > "$CAND_WRAPPER"
chmod +x "$REF_WRAPPER" "$CAND_WRAPPER"
sha256sum "$REF_WRAPPER" "$CAND_WRAPPER" > "$RUN/wrappers.sha256"
export PATH="$CAND_PREFIX/bin:$PATH"
export IVERILOG="$CAND_PREFIX/bin/iverilog"
export IVERILOG_VPI="$CAND_PREFIX/bin/iverilog-vpi"
export UVM_DPI="$CAND_PREFIX/lib/ivl/uvm_dpi.vpi"
unset IVL_PERF_STATS
tar -xzf "$ARCHIVES/candidate.tar.gz" -C "$CAND_SRC"
tar -xzf "$ARCHIVES/uvm-core.tar.gz" -C "$CAND_SRC/uvm-core"
{
  cd "$CAND_SRC"
  find . -type f -print0 | sort -z | xargs -0 sha256sum
} > "$RUN/source-files.sha256"
run_stage screen 1
run_stage result 5
printf 'primary_metric=%s\n' "$(sed -n 's/^primary_metric=//p' "$RUN/results/result.gate.txt")" > "$RUN/measurement-summary.txt"
printf 'all_required_measurement_gates=PASS\n' >> "$RUN/measurement-summary.txt"
sha256sum "$RUN/source-manifest.txt" "$RUN/source-files.sha256" \
  "$RUN/binary.sha256" "$RUN/wrappers.sha256" "$RUN/measurement-summary.txt" \
  "$RUN/results"/* "$RUN/logs"/* > "$RUN/logs.sha256"
rmdir "$TMPDIR"
