#!/usr/bin/env bash
#SBATCH --job-name=a5-wp0-base16
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-json-baseline-33bb0fa-20261014/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-json-baseline-33bb0fa-20261014/logs/%x-%j.err
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-json-baseline-33bb0fa-20261014
ARCHIVE="$RUN/input/source.tar.gz"
SRC="$RUN/source"
PREFIX="$RUN/install"
LOGS="$RUN/logs"
LISTS="$RUN/lists"
mkdir -p "$LOGS" "$LISTS"
cd "$RUN"

printf 'head=33bb0fa640d8862198ea88ef86dd3e4674f791ee\n' > baseline-summary.txt
printf 'resources=2 CPUs, 4 GiB RAM, 2 hours; per-test timeout=300 seconds\n' >> baseline-summary.txt
printf 'baseline_commit=33bb0fa640d8862198ea88ef86dd3e4674f791ee\n' > source-manifest.txt
(cd "$RUN/input" && sha256sum -c SHA256SUMS)
printf 'source_archive_sha256=%s\n' "$(sha256sum "$ARCHIVE" | awk '{print $1}')" >> source-manifest.txt

run_stage() {
  local name="$1" limit="$2" rc=0
  shift 2
  {
    printf 'command='
    printf '%q ' "$@"
    printf '\n'
  } > "$LOGS/$name.command"
  printf 'BEGIN %s %s\n' "$name" "$(date -u +%FT%TZ)" | tee -a baseline-summary.txt
  set +e
  /usr/bin/time -v -o "$LOGS/$name.resource" \
    timeout --signal=TERM --kill-after=15s "$limit" "$@" > "$LOGS/$name.log" 2>&1
  rc=$?
  set -e
  printf 'exit_code=%s\n' "$rc" > "$LOGS/$name.status"
  printf 'END %s exit_code=%s %s\n' "$name" "$rc" "$(date -u +%FT%TZ)" | tee -a baseline-summary.txt
  if [[ "$rc" -ne 0 ]]; then
    printf 'FAILED_STAGE=%s\n' "$name" | tee -a baseline-summary.txt
    exit "$rc"
  fi
}

mkdir -p "$SRC"
run_stage extract 300s tar -xzf "$ARCHIVE" -C "$SRC"
run_stage autoconf 600s bash -c 'cd "$1" && sh ./autoconf.sh' bash "$SRC"
export CFLAGS='-g0 -O2'
export CXXFLAGS='-g0 -O2'
run_stage configure 900s bash -c 'cd "$1" && ./configure --prefix="$2" --enable-libveriuser' bash "$SRC" "$PREFIX"
run_stage build 3600s make -C "$SRC" -j2
run_stage install 600s make -C "$SRC" install

python3 - "$SRC/ivtest/regress-vvp.list" "$RUN/failing-test-names.txt" "$LISTS" <<'PY'
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1])
names_path = pathlib.Path(sys.argv[2])
lists_dir = pathlib.Path(sys.argv[3])
expected = {line.strip() for line in names_path.read_text().splitlines() if line.strip()}
found = {}
for raw in manifest.read_text().splitlines():
    line = raw.split("#", 1)[0].strip()
    if not line:
        continue
    key = line.split()[0]
    if key in expected:
        found[key] = line
missing = expected - found.keys()
if missing:
    raise SystemExit("missing from regress-vvp.list: " + ", ".join(sorted(missing)))
for key in sorted(expected):
    (lists_dir / (key + ".list")).write_text(found[key] + "\n")
print(f"selected={len(expected)}")
PY

export PATH="$PREFIX/bin:$PATH"
export IVERILOG="$PREFIX/bin/iverilog"
export VVP="$PREFIX/bin/vvp"
printf 'test\tbaseline_exit_code\n' > "$RUN/baseline-results.tsv"
failed=0
for name in $(cat "$RUN/failing-test-names.txt"); do
  rc=0
  (
    cd "$SRC/ivtest"
    /usr/bin/time -v -o "$LOGS/$name.resource" \
      timeout --signal=TERM --kill-after=15s 300s \
      python3 ./vvp_reg.py "$LISTS/$name.list"
  ) > "$LOGS/$name.log" 2>&1 || rc=$?
  printf '%s\t%s\n' "$name" "$rc" >> "$RUN/baseline-results.tsv"
  if [[ "$rc" -ne 1 ]]; then
    failed=1
  fi
done
if [[ "$failed" -ne 0 ]]; then
  printf 'comparison=INCONCLUSIVE; at least one test did not reproduce as a normal one-test failure\n' | tee -a baseline-summary.txt
  exit 2
fi
printf 'comparison=REPRODUCED; all 16 full-suite failures are present on origin/main baseline\n' | tee -a baseline-summary.txt
sha256sum "$RUN/baseline-summary.txt" "$RUN/source-manifest.txt" "$RUN/failing-test-names.txt" "$RUN/baseline-results.tsv" "$LOGS"/* > "$RUN/logs.sha256"
