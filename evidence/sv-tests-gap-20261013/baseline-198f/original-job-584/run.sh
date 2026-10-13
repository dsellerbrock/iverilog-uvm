#!/usr/bin/env bash
#SBATCH --job-name=a3-svtests-start
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=3G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-main-20261012-2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-main-20261012-2/logs/slurm-%j.out
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-main-20261012-2
ROOT=$RUN/corpus/repo
UVM=$ROOT/third_party/tests/uvm
MAIN=$RUN/../perf-pre526-main-20261012-2/install/main
mkdir -p "$RUN/tool-bin" "$RUN/evidence"
printf '#!/bin/sh\nexec %s/bin/iverilog "$@"\n' "$MAIN" > "$RUN/tool-bin/iverilog"
printf '#!/bin/sh\nexec %s/bin/vvp "$@"\n' "$MAIN" > "$RUN/tool-bin/vvp"
chmod +x "$RUN/tool-bin/iverilog" "$RUN/tool-bin/vvp"
# The archive carries the pinned contents. Recreate a minimal local Git index so the harness can enumerate tests and verify UVM provenance.
git -C "$UVM" init -q
git -C "$UVM" add -f .
git -C "$UVM" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Pinned UVM evidence snapshot'
uvm_sha=$(git -C "$UVM" rev-parse HEAD)
git -C "$ROOT" init -q
git -C "$ROOT" add -f tests conf tools
# Preserve original upstream corpus commit and UVM commit in a provenance file.
printf 'sv-tests=c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7\nuvm=656f20d087370a7c742e00188d20bbf30fa95339\n' > "$RUN/logs/provenance.txt"
git -C "$ROOT" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Pinned sv-tests test and runner snapshot'
git -C "$ROOT" update-index --add --cacheinfo "160000,$uvm_sha,third_party/tests/uvm"
git -C "$ROOT" -c user.name='A3 evidence' -c user.email='a3-evidence@local' commit -qm 'Record pinned UVM snapshot'
printf 'synthetic_uvm=%s\n' "$uvm_sha" >> "$RUN/logs/provenance.txt"
{
  hostname
  python3 --version
  "$MAIN/bin/iverilog" -V 2>&1 | sed -n "1,2p"
  "$MAIN/bin/vvp" -V 2>&1 | sed -n "1,2p"
  sha256sum "$MAIN/bin/iverilog" "$MAIN/bin/vvp"
} > "$RUN/logs/environment.txt"
python3 "$RUN/run_icarus_svtests.py" \
  --sv-tests "$ROOT" \
  --evidence "$RUN/evidence/current-main" \
  --runner-safe "$RUN/runner-safe" \
  --python-bin /usr/bin/python3 | tee "$RUN/logs/summary.log"
