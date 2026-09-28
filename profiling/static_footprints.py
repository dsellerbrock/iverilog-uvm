from collections import Counter, defaultdict
from pathlib import Path
import json, re, sys

IMAGE = Path(sys.argv[1])
OUT = Path(__file__).with_name('static-summary.json')
lines = IMAGE.read_text().splitlines()
variable = {}
for line in lines:
    match = re.match(r'^(v0x[0-9a-f]+(?:_\d+)?)\s+\.(?:var|net|array)(?:/\w+)?\s+"([^"]+)"', line)
    if match:
        variable[match.group(1)] = match.group(2)

processes = []
start = None
for line_number, line in enumerate(lines, 1):
    match = re.match(r'^T_(\d+) ;', line)
    if match:
        start = {'id': int(match.group(1)), 'line': line_number, 'ops': Counter(), 'reads': set(), 'nba_writes': set(), 'immediate_writes': set(), 'other_writes': set(), 'side_effects': set(), 's2_bases': defaultdict(set)}
    if start is None:
        continue
    op = re.search(r'%([A-Za-z0-9_./]+)', line)
    if op:
        name = op.group(1)
        start['ops'][name] += 1
        ref = re.search(r'v0x[0-9a-f]+(?:_\d+)?', line)
        if ref:
            address = ref.group(0)
            if name.startswith('load'):
                start['reads'].add(address)
            elif name.startswith('assign'):
                start['nba_writes'].add(address)
                if name == 'assign/vec4/off/s2':
                    base = re.search(r',\s*(-?\d+)\s*;', line)
                    assert base, (line_number, line)
                    start['s2_bases'][address].add(int(base.group(1)))
            elif name.startswith('store'):
                start['immediate_writes'].add(address)
            elif name.startswith(('set', 'force', 'release')):
                start['other_writes'].add(address)
        if name.startswith(('vpi_call', 'fork', 'join', 'wait', 'delay', 'disable', 'call', 'ufunc', 'random', 'syscall')):
            start['side_effects'].add(name)
    if re.match(r'^\s*\.thread T_\d+', line):
        start['reads'] = sorted(start['reads'])
        start['nba_writes'] = sorted(start['nba_writes'])
        start['immediate_writes'] = sorted(start['immediate_writes'])
        start['other_writes'] = sorted(start['other_writes'])
        start['side_effects'] = sorted(start['side_effects'])
        start['s2_bases'] = {k: sorted(v) for k,v in start['s2_bases'].items()}
        start['ops'] = dict(start['ops'])
        processes.append(start)
        start = None

writes = defaultdict(list)
for p in processes:
    for address in p['nba_writes']:
        writes[address].append(p['id'])
by_name = defaultdict(list)
for address, name in variable.items():
    by_name[name].append(address)
def named_writers(name):
    return {address: writes[address] for address in by_name[name]}
def named_s2_bases(name):
    return {address: {p['id']: p['s2_bases'][address]
                      for p in processes if address in p['s2_bases']}
            for address in by_name[name]}
summary = {
    'image': str(IMAGE),
    'processes': len(processes),
    'total_opcodes': sum(sum(p['ops'].values()) for p in processes),
    'total_nba_ops': sum(sum(n for op,n in p['ops'].items() if op.startswith('assign')) for p in processes),
    'total_immediate_store_ops': sum(sum(n for op,n in p['ops'].items() if op.startswith('store')) for p in processes),
    'processes_with_fork': sum(any(x.startswith('fork') for x in p['side_effects']) for p in processes),
    'processes_with_vpi': sum(any(x.startswith('vpi_call') for x in p['side_effects']) for p in processes),
    'nba_writers_by_x_reg_address': named_writers('x_reg'),
    'nba_writers_by_y_reg_address': named_writers('y_reg'),
    'nba_writers_by_sum_reg_address': named_writers('sum_reg'),
    's2_bases_by_x_reg_address': named_s2_bases('x_reg'),
    's2_bases_by_y_reg_address': named_s2_bases('y_reg'),
    's2_bases_by_sum_reg_address': named_s2_bases('sum_reg'),
    'popular_nba_destinations': sorted(((k,variable.get(k),len(v)) for k,v in writes.items()), key=lambda x:-x[2])[:15],
    'opcode_counts': Counter(op for p in processes for op,n in p['ops'].items() for _ in range(n)).most_common(25),
}
OUT.write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
