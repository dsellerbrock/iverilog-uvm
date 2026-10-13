#!/usr/bin/env python3
import argparse, collections, json, os, pathlib, re, shutil, subprocess

p = argparse.ArgumentParser()
p.add_argument('--sv-tests', type=pathlib.Path, required=True)
p.add_argument('--evidence', type=pathlib.Path, required=True)
p.add_argument('--runner-safe', type=pathlib.Path, required=True)
p.add_argument('--python-bin', type=pathlib.Path, required=True)
a = p.parse_args()
root, out = a.sv_tests.resolve(), a.evidence.resolve()

def git(*args):
    return subprocess.check_output(['git', *map(str, args)]).decode().strip()

def meta(path):
    result = {}
    for line in path.read_text(errors='replace').splitlines():
        m = re.match(r'^:([A-Za-z_-]+):\s*(.+)', line)
        if m: result[m.group(1).lower()] = m.group(2).strip()
    return result

manifest = sorted(pathlib.Path(x.decode()) for x in subprocess.check_output(
    ['git', '-C', str(root), 'ls-files', '-z', '--', ':(glob)tests/**/*.sv']).split(b'\0') if x)
uvm_src = root / 'third_party/tests/uvm'
uvm_dst = out / 'third_party/tests/uvm'
# macOS tar streams may carry AppleDouble sidecars; strip those metadata files
# and update the synthetic Git snapshot before validating the UVM gitlink.
removed_uvm = False
for sidecar in root.rglob('._*'):
    if sidecar.is_file() and '.git' not in sidecar.parts:
        sidecar.unlink()
        if sidecar.is_relative_to(uvm_src): removed_uvm = True
for sidecar in root.rglob('.DS_Store'):
    if sidecar.is_file() and '.git' not in sidecar.parts: sidecar.unlink()
if removed_uvm:
    subprocess.run(['git', '-C', str(uvm_src), 'add', '-u'], check=True)
    subprocess.run(['git', '-C', str(uvm_src), '-c', 'user.name=A3 evidence', '-c',
                    'user.email=a3-evidence@local', 'commit', '-qm',
                    'Remove archive metadata sidecars'], check=True)
    uvm_sha = git('-C', uvm_src, 'rev-parse', 'HEAD')
    subprocess.run(['git', '-C', str(root), 'update-index', '--cacheinfo',
                    f'160000,{uvm_sha},third_party/tests/uvm'], check=True)
    subprocess.run(['git', '-C', str(root), '-c', 'user.name=A3 evidence', '-c',
                    'user.email=a3-evidence@local', 'commit', '-qm',
                    'Update synthetic UVM gitlink'], check=True)
uvm_expected = git('-C', root, 'rev-parse', 'HEAD:third_party/tests/uvm')
uvm_actual = git('-C', uvm_src, 'rev-parse', 'HEAD')
if len(manifest) != 1027: raise SystemExit(f'unexpected manifest count {len(manifest)}')
uvm_tests = [t for t in manifest if 'uvm' in set(meta(root / t).get('tags', '').split())]
if len(uvm_tests) != 104: raise SystemExit(f'unexpected UVM count {len(uvm_tests)}')
if uvm_actual != uvm_expected or git('-C', uvm_src, 'status', '--porcelain=v2', '--untracked-files=all'):
    raise SystemExit('pinned UVM checkout mismatch or dirty')
out.mkdir(parents=True, exist_ok=True)
shutil.copytree(root / 'tests', out / 'tests', dirs_exist_ok=True)
shutil.copytree(uvm_src, uvm_dst, dirs_exist_ok=True, ignore=shutil.ignore_patterns('.git'))
(out / 'all-tests.txt').write_text(''.join(f'{t}\n' for t in manifest))
env = os.environ.copy()
tool_bin = out / 'tool-bin'
env.update({
    'OUT_DIR': str(out / 'out'), 'CONF_DIR': str(root / 'conf'),
    'TESTS_DIR': str(out / 'tests'), 'RUNNERS_DIR': str(root / 'tools/runners'),
    'THIRD_PARTY_DIR': str(root / 'third_party'),
    'PYTHONPATH': str(root / 'tools'), 'PYTHONDONTWRITEBYTECODE': '1',
    'PYTHONPYCACHEPREFIX': str(out / 'pycache'),
    'PATH': os.pathsep.join([str(tool_bin), '/usr/local/bin', '/usr/bin', '/bin', '/usr/sbin', '/sbin'])})
logs = out / 'out/logs/Icarus'
for i, rel in enumerate(manifest, 1):
    test_rel = pathlib.Path(str(rel)[len('tests/'):])
    log = logs / (str(test_rel) + '.log')
    log.parent.mkdir(parents=True, exist_ok=True)
    cmd = [str(a.python_bin), str(a.runner_safe), '--runner', 'Icarus', '--test', str(test_rel), '--out', str(log), '--quiet']
    subprocess.run(cmd, cwd=root, env=env, check=True)
    if i % 100 == 0 or i == len(manifest): print(f'completed {i}/{len(manifest)}', flush=True)
classes = collections.Counter()
uvm_classes = collections.Counter()
applicable = passed = 0
for rel in manifest:
    test_rel = pathlib.Path(str(rel)[len('tests/'):])
    fields = {}
    for line in (logs / (str(test_rel) + '.log')).read_text(errors='replace').splitlines():
        if ': ' in line:
            k, v = line.split(': ', 1); fields[k] = v
    cls = fields.get('result_class', 'MISSING_CLASS')
    classes[cls] += 1
    applicable += fields.get('applicable') == '1'
    passed += fields.get('test_passed') == '1'
    if rel in uvm_tests: uvm_classes[cls] += 1
nonproblematic = sum(classes[k] for k in ('VERIFIED_RUNTIME', 'STATIC_ACCEPT', 'ACCEPTANCE_ONLY', 'EXPECTED_REJECT_UNVERIFIED'))
summary = {'applicable':applicable, 'passed':passed, 'failed_applicable':applicable-passed, 'pass_rate_percent':round(100*passed/applicable, 2) if applicable else None, 'corpus_commit':'c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7', 'test_count':len(manifest), 'result_classes':dict(sorted(classes.items())), 'nonproblematic':nonproblematic, 'problematic':len(manifest)-nonproblematic, 'uvm_count':len(uvm_tests), 'uvm_result_classes':dict(sorted(uvm_classes.items()))}
(out / 'summary.json').write_text(json.dumps(summary, indent=2, sort_keys=True)+'\n')
print(json.dumps(summary, indent=2, sort_keys=True))
