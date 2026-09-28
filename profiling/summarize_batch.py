from collections import defaultdict
from pathlib import Path
import json
import re
import statistics
import sys

rows = []
assert len(sys.argv) == 3, 'usage: summarize_batch.py PROFILE_STDERR SIM_STDOUT'
for line in Path(sys.argv[1]).read_text().splitlines():
    match = re.fullmatch(r'BATCH_PROFILE time=(\d+) scope=(.+) ns=(\d+)', line)
    if match:
        rows.append((int(match[1]), match[2], int(match[3])))
assert rows and len({time for time, _, _ in rows}) == 1
hash_match = re.search(r'\bhash=([0-9a-fA-F]+)\b', Path(sys.argv[2]).read_text())
assert hash_match

lanes = defaultdict(lambda: {'xy_ns': 0, 'sum_ns': 0})
for _, scope, ns in rows:
    match = re.search(r'gen_full_adders\[(\d+)\]\.\$unm_blk_(11|19)$', scope)
    if match:
        lanes[int(match[1])]['xy_ns' if match[2] == '11' else 'sum_ns'] += ns
assert len(lanes) == 46
assert all(item['xy_ns'] and item['sum_ns'] for item in lanes.values())

costs = [item['xy_ns'] + item['sum_ns'] for item in lanes.values()]
def lpt(cores):
    bins = [0] * cores
    for cost in sorted(costs, reverse=True):
        bins[bins.index(min(bins))] += cost
    return sorted(bins)

result = {
    'sample_time_ps': rows[0][0],
    'dispatches': len(rows),
    'total_thread_ns': sum(ns for _, _, ns in rows),
    'lane_context_dispatches': sum(1 for _, scope, _ in rows if re.search(r'gen_full_adders\[\d+\]\.\$unm_blk_(11|19)$', scope)),
    'lane_context_ns': sum(costs),
    'xy_context_ns': sum(item['xy_ns'] for item in lanes.values()),
    'sum_context_ns': sum(item['sum_ns'] for item in lanes.values()),
    'lane_cost_ns': {str(i): lanes[i] for i in sorted(lanes)},
    'lane_total_ns_p10_median_p90': [sorted(costs)[4], statistics.median(costs), sorted(costs)[41]],
    'ideal_lpt_payload_ns': {str(n): lpt(n) for n in (1, 2, 4)},
    'hash': hash_match[1],
}
Path(__file__).with_name('batch-profile-summary.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: value for key, value in result.items() if key != 'lane_cost_ns'}, indent=2))
