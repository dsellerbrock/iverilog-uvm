#!/usr/bin/env bash
#SBATCH --job-name=a5-z3-stab
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-z3-stability-64eb2c8cd/logs/diagnose-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-z3-stability-64eb2c8cd/logs/diagnose-%j.err
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-z3-stability-64eb2c8cd
COMPILER=/home/dsell/toolchains/iverilog-a5-wp0-281d1bca-off/bin/iverilog
STATS_VVP=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-stats-current-verify-47bc-20261014-r1/install/bin/vvp
cd "$RUN"
sha256sum -c source.sha256
printf 'host=%s\n' "$(hostname)"
printf 'date_utc=%s\n' "$(date -u +%FT%TZ)"
printf 'stats_vvp_source_revision=39d959d3a (vvp/ unchanged through 64eb2c8cd)\n'
printf 'candidate_benchmark_source_revision=64eb2c8cd\n'
sha256sum "$COMPILER" "$STATS_VVP" > binary.sha256
"$COMPILER" -g2017 -s main -o "$RUN/randomize_z3.vvp" "$RUN/randomize_z3.sv"
for i in 1 2 3 4 5; do
  IVL_PERF_STATS=1 /usr/bin/perf stat -x, --no-big-num -e task-clock \
    -o "$RUN/perf-$i.csv" -- "$STATS_VVP" -n "$RUN/randomize_z3.vvp" \
    > "$RUN/stdout-$i" 2> "$RUN/stats-$i.log"
done
python3 - "$RUN" <<'PY'
import csv
import hashlib
import json
import re
import sys
from pathlib import Path
root=Path(sys.argv[1])
outputs=[]
rows=[]
for i in range(1,6):
    outputs.append((root/f'stdout-{i}').read_bytes())
    stderr=(root/f'stats-{i}.log').read_text(errors='replace')
    match=re.search(r'^VVP_PERF_STATS (\{.*\})$',stderr,re.M)
    assert match, (i,stderr[-1000:])
    stats=json.loads(match.group(1))
    with (root/f'perf-{i}.csv').open(newline='') as stream:
        perf=list(csv.reader(stream))
    task=next(float(row[0]) for row in perf if len(row)>2 and row[2].strip().split(':',1)[0]=='task-clock')
    z3=stats['z3']
    assert z3['contexts']>0 and z3['checks']>0 and z3['model_evaluations']>0
    rows.append((task,z3))
assert all(output==outputs[0] for output in outputs)
summary=root/'diagnostic-summary.txt'
with summary.open('w') as report:
    report.write('All five stats-enabled runs produced byte-identical stdout.\n')
    report.write('run,task_clock_ms,z3_contexts,z3_checks,z3_model_evaluations,stdout_sha256\n')
    for i,(task,z3) in enumerate(rows,1):
        digest=hashlib.sha256(outputs[i-1]).hexdigest()
        report.write(f"{i},{task:.3f},{z3['contexts']},{z3['checks']},{z3['model_evaluations']},{digest}\n")
print(summary.read_text(),end='')
PY
sha256sum "$RUN/diagnostic-summary.txt" > "$RUN/diagnostic-summary.sha256"
