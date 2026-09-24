#!/usr/bin/env python3
"""Fresh compile-only repeat of the frozen 44 Caliptra/Adams unit census."""
import hashlib, json, os, shlex, subprocess, time
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'evidence/caliptra-icarus-dv-baseline-20260923'
OLD = json.loads((ROOT / 'evidence/caliptra-full-dv-unit-census-20260923/results.json').read_text())
INV = json.loads((ROOT / 'evidence/caliptra-full-dv-inventory-20260923/inventory.json').read_text())
REPOS = {r['name']: Path(r['root']) for r in INV['repositories']}
CALIPTRA = REPOS['caliptra_v2.1.2']
ABR = CALIPTRA / 'submodules/adams-bridge'
ENV = os.environ.copy()
ENV.update(CALIPTRA_ROOT=str(CALIPTRA), CALIPTRA_AXI4PC_DIR=str(CALIPTRA/'src/integration/tb'), CALIPTRA_PRIM_ROOT=str(CALIPTRA/'src/caliptra_prim_generic'), CALIPTRA_PRIM_MODULE_PREFIX='caliptra_prim_generic', ADAMSBRIDGE_ROOT=str(ABR))
result_path=OUT/'unit-census-results.json'
rows=json.loads(result_path.read_text())['entries'] if result_path.exists() else []
done={r['case'] for r in rows}
for n, prior in enumerate(OLD['tests'], 1):
    case=prior['output_dir'].split('/')[-1]
    if case in done:
        continue
    if not prior.get('command'):
        rows.append({'case':case,'repository':prior['repository'],'filelist':prior['filelist'],'top':prior.get('top_candidate'),'classification':'setup','prior_classification':'setup','exit_code':None,'timed_out':False,'reason':prior.get('reason','No runnable command in frozen census record')})
        result_path.write_text(json.dumps({'source_inventory_sha256':OLD['inventory_sha256'],'entries':rows},indent=2)+'\n')
        print(f"{n}/{len(OLD['tests'])} {case}: setup (no command)",flush=True)
        continue
    oldargv=shlex.split(prior['command'])
    caseout=OUT/'unit-census'/case
    caseout.mkdir(parents=True,exist_ok=True)
    argv=[]
    i=0
    while i < len(oldargv):
        if oldargv[i] == '-o':
            argv += ['-o',str(caseout/'design.vvp')]; i += 2
        else:
            argv.append(oldargv[i]); i += 1
    row={'case':case,'repository':prior['repository'],'filelist':prior['filelist'],'top':prior.get('top_candidate'),'argv':argv,'timeout_seconds':60,'prior_classification':prior['classification']}
    start=time.monotonic()
    try:
        p=subprocess.run(argv,cwd=ROOT,env=ENV,capture_output=True,text=True,timeout=60)
        row.update(exit_code=p.returncode,timed_out=False,elapsed_seconds=round(time.monotonic()-start,3),stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired as e:
        row.update(exit_code=None,timed_out=True,elapsed_seconds=round(time.monotonic()-start,3),stdout=e.stdout or '',stderr=e.stderr or '')
        if isinstance(row['stdout'],bytes): row['stdout']=row['stdout'].decode(errors='replace')
        if isinstance(row['stderr'],bytes): row['stderr']=row['stderr'].decode(errors='replace')
    row['classification']=prior['classification'] if prior['classification'] in ('setup','unsupported') else ('pass' if row['exit_code']==0 and not row['timed_out'] else ('timeout' if row['timed_out'] else 'fail'))
    (caseout/'stdout.txt').write_text(row['stdout']); (caseout/'stderr.txt').write_text(row['stderr'])
    row['stdout_path']=str((caseout/'stdout.txt').relative_to(ROOT)); row['stderr_path']=str((caseout/'stderr.txt').relative_to(ROOT))
    row['first_diagnostic']=next((line.strip() for line in row['stderr'].splitlines() if 'error:' in line or 'sorry:' in line),None)
    image=caseout/'design.vvp'
    if image.exists():
        row['image_sha256']=hashlib.sha256(image.read_bytes()).hexdigest(); image.unlink()
    row.pop('stdout'); row.pop('stderr')
    rows.append(row)
    result_path.write_text(json.dumps({'source_inventory_sha256':OLD['inventory_sha256'],'entries':rows},indent=2)+'\n')
    print(f"{n}/{len(OLD['tests'])} {case}: {row['classification']} ({row['elapsed_seconds']:.2f}s)",flush=True)
counts={k:sum(r['classification']==k for r in rows) for k in ('pass','fail','timeout')}
summary={'counts':counts,'total':len(rows),'note':'Fresh compile-only repeat. Compilation/elaboration does not count as runtime DV.'}
(OUT/'unit-census-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))
