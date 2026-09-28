import json
from pathlib import Path
import resource
import statistics
import subprocess
import sys
import time

assert len(sys.argv) in (4, 5), 'usage: compare_env_off.py BASE_VVP CANDIDATE_VVP IMAGE [OUTPUT_JSON]'
base, candidate, image = sys.argv[1:4]
output = Path(sys.argv[4]) if len(sys.argv) == 5 else Path(__file__).with_name('env-off-overhead.json')

def run(binary):
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    start = time.perf_counter()
    proc = subprocess.run([binary, image], capture_output=True, text=True, check=True)
    wall = time.perf_counter() - start
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    assert 'hash=cc373498' in proc.stdout and not proc.stderr
    return {'wall_s': wall,
            'cpu_s': (after.ru_utime + after.ru_stime) -
                     (before.ru_utime + before.ru_stime)}

run(base)
run(candidate)
pairs = []
for index in range(7):
    order = [('base', base), ('candidate', candidate)]
    if index % 2:
        order.reverse()
    pair = {name: run(binary) for name, binary in order}
    pairs.append(pair)

result = {
    'base': base,
    'candidate': candidate,
    'image': image,
    'pairs': pairs,
    'median_base_wall_s': statistics.median(p['base']['wall_s'] for p in pairs),
    'median_candidate_wall_s': statistics.median(p['candidate']['wall_s'] for p in pairs),
    'median_base_cpu_s': statistics.median(p['base']['cpu_s'] for p in pairs),
    'median_candidate_cpu_s': statistics.median(p['candidate']['cpu_s'] for p in pairs),
    'median_paired_wall_ratio': statistics.median(
        p['candidate']['wall_s']/p['base']['wall_s'] for p in pairs),
    'median_paired_cpu_ratio': statistics.median(
        p['candidate']['cpu_s']/p['base']['cpu_s'] for p in pairs),
}
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: value for key, value in result.items() if key != 'pairs'}, indent=2))
