#!/usr/bin/env python3
"""Run CSRNG legacy registrations with private work and logs."""
import json
import pathlib
import subprocess

repo = pathlib.Path('/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926')
base = pathlib.Path('/private/tmp/ot-csrng-index-20260929')
out = base / 'dynamic-legacy-focus'
out.mkdir(exist_ok=True)
link = out / 'ivltests'
if not link.exists():
    link.symlink_to(repo / 'ivtest/ivltests', target_is_directory=True)

results = []
listing = repo / 'ivtest/regress-class-packed-enum-property-index-focus-legacy.list'
for line in listing.read_text().splitlines():
    if not line.strip() or line.startswith('#'):
        continue
    name, kinds, directory, *options = line.split()
    kind, *args = kinds.split(',')
    stem = out / name
    cmd = [str(repo / 'driver/iverilog'), '-B' + str(base / 'in-tree-bin'),
           '-BM' + str(repo / 'vpi'), '-o', str(stem.with_suffix('.vvp')),
           *args, '-D__ICARUS_UNSIZED__',
           directory + '/' + name + '.v']
    comp = subprocess.run(cmd, cwd=out, capture_output=True, check=False)
    (out / (name + '-compile-stderr.log')).write_bytes(comp.stderr)
    run = None
    mismatch = []
    if kind == 'normal' and comp.returncode == 0:
        run = subprocess.run([str(repo / 'vvp/vvp'),
                              str(stem.with_suffix('.vvp'))],
                             cwd=out, capture_output=True, check=False)
        (out / (name + '-runtime-stdout.log')).write_bytes(run.stdout)
        gold_name = next((o.removeprefix('gold=') for o in options
                          if o.startswith('gold=')), None)
        if gold_name and run.stdout != (repo / 'ivtest/gold' / gold_name).read_bytes():
            mismatch.append('stdout')
    passed = (comp.returncode != 0 if kind == 'CE' else
              comp.returncode == 0 and run is not None and run.returncode == 0)
    passed = passed and not mismatch
    results.append({'name': name, 'pass': passed,
                    'compile_exit': comp.returncode,
                    'runtime_exit': None if run is None else run.returncode,
                    'mismatch': mismatch})
    print(('PASS' if passed else 'FAIL') + ' ' + name)

(out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
print(f"total={len(results)} failed={sum(not item['pass'] for item in results)}")
