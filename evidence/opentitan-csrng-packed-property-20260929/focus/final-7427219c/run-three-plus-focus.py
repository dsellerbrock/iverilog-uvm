#!/usr/bin/env python3
"""Run only CSRNG regression failures and focused controls with private outputs."""
import json
import pathlib
import subprocess

REPO = pathlib.Path('/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926')
HERE = pathlib.Path('/private/tmp/ot-csrng-index-20260929')
OUT = HERE / 'three-plus-focus'
OUT.mkdir(exist_ok=True)
source_link = OUT / 'ivltests'
if not source_link.exists():
    source_link.symlink_to(REPO / 'ivtest/ivltests', target_is_directory=True)

names = [
    'sv_concat_object_lvalue_unknown_offset',
    'sv_selected_vif_edge_invalid_real_index_2017',
    'sv_selected_vif_edge_invalid_real_index_2023',
    'sv_class_fixed_array_container_packed_select_oob',
]
for listing in [HERE / 'adjacent-packed-property-vvp.list',
                REPO / 'ivtest/regress-class-packed-enum-property-index-focus-vvp.list']:
    for line in listing.read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            names.append(line.split()[0])
names = list(dict.fromkeys(names))

configs = {}
for listing in [REPO / 'ivtest/regress-vvp.list',
                HERE / 'adjacent-packed-property-vvp.list',
                REPO / 'ivtest/regress-class-packed-enum-property-index-focus-vvp.list']:
    for line in listing.read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0] in names:
            configs[fields[0]] = REPO / 'ivtest' / fields[1]

results = []
for name in names:
    cfg = json.loads(configs[name].read_text())
    stem = OUT / name
    cmd = [str(REPO / 'driver/iverilog'),
           '-B' + str(HERE / 'in-tree-bin'),
           '-BM' + str(REPO / 'vpi'),
           '-o', str(stem.with_suffix('.vvp')),
           *cfg.get('iverilog-args', []),
           '-D__ICARUS_UNSIZED__',
           'ivltests/' + cfg['source']]
    comp = subprocess.run(cmd, cwd=OUT, capture_output=True, check=False)
    (OUT / (name + '-iverilog-stdout.log')).write_bytes(comp.stdout)
    (OUT / (name + '-iverilog-stderr.log')).write_bytes(comp.stderr)
    streams = {'iverilog-stdout': comp.stdout,
               'iverilog-stderr': comp.stderr}
    runtime = None
    if cfg['type'] == 'normal' and comp.returncode == 0:
        vcmd = [str(REPO / 'vvp/vvp'),
                *cfg.get('vvp-args', []),
                str(stem.with_suffix('.vvp')),
                *cfg.get('vvp-args-extended', [])]
        runtime = subprocess.run(vcmd, cwd=OUT, capture_output=True, check=False)
        streams['vvp-stdout'] = runtime.stdout
        streams['vvp-stderr'] = runtime.stderr
        (OUT / (name + '-vvp-stdout.log')).write_bytes(runtime.stdout)
        (OUT / (name + '-vvp-stderr.log')).write_bytes(runtime.stderr)
    mismatches = []
    if cfg.get('gold'):
        for label, actual in streams.items():
            path = REPO / 'ivtest/gold' / (cfg['gold'] + '-' + label + '.gold')
            expected = path.read_bytes() if path.exists() else b''
            if actual != expected:
                mismatches.append(label)
    elif cfg['type'] == 'normal' and runtime is not None:
        if b'PASSED' not in runtime.stdout.splitlines():
            mismatches.append('missing PASSED')
    ok = ((cfg['type'] == 'CE' and 0 < comp.returncode < 256) or
          (cfg['type'] == 'normal' and comp.returncode == 0 and
           runtime is not None and runtime.returncode == 0))
    ok = ok and not mismatches
    result = {'name': name, 'pass': ok, 'compile_exit': comp.returncode,
              'runtime_exit': None if runtime is None else runtime.returncode,
              'mismatches': mismatches}
    results.append(result)
    print(('PASS' if ok else 'FAIL') + ' ' + name +
          (' mismatches=' + ','.join(mismatches) if mismatches else ''))

(OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
print(f"total={len(results)} failed={sum(not r['pass'] for r in results)}")
