#!/usr/bin/env python3
"""Focused reproducibility check for +ntb_random_seed."""
import pathlib, subprocess, sys, tempfile
root=pathlib.Path(__file__).resolve().parent.parent
bindir=root/'local-install/bin'
def run(cmd):
 p=subprocess.run([str(x) for x in cmd],text=True,capture_output=True,timeout=15)
 return p.returncode,p.stdout,p.stderr
with tempfile.TemporaryDirectory(prefix='ivl-root-seed-') as td:
 td=pathlib.Path(td)
 for edition in ('2017','2023'):
  basic=td/f'basic-{edition}.vvp'; tree=td/f'tree-{edition}.vvp'
  for out,name in ((basic,'sv_runtime_root_seed'),(tree,'sv_runtime_root_seed_hierarchy')):
   rc,so,se=run([bindir/'iverilog',f'-g{edition}','-s','test','-o',out,
                 root/'ivtest/ivltests'/f'{name}.v'])
   if rc: raise SystemExit(f'{edition} compile failed: {se}')
  default=run([bindir/'vvp',basic])
  if default[:2] != (0,'seed=-1 70eedf01 04ae5bd4 a939a196 ab9d557b\n'):
   raise SystemExit(f'{edition} default sequence changed: {default}')
  one=run([bindir/'vvp',basic,'+ntb_random_seed=1'])
  if one != run([bindir/'vvp',basic,'+ntb_random_seed=1']):
   raise SystemExit(f'{edition} same seed not reproducible')
  if one != run([bindir/'vvp','+ntb_random_seed=1',basic]):
   raise SystemExit(f'{edition} seed argument position changed its meaning')
  two=run([bindir/'vvp',basic,'+ntb_random_seed=2'])
  if one[0] or two[0] or one[1] == two[1]:
   raise SystemExit(f'{edition} distinct seeds do not differ')
  for boundary,display in (('0','0'),('4294967295','-1')):
   rc,so,se=run([bindir/'vvp',basic,f'+ntb_random_seed={boundary}'])
   if rc or not so.startswith(f'seed={display} '):
    raise SystemExit(f'{edition} valid boundary seed failed: {boundary}: {(rc,so,se)}')
  t1=run([bindir/'vvp',tree,'+ntb_random_seed=1'])
  if t1 != run([bindir/'vvp',tree,'+ntb_random_seed=1']):
   raise SystemExit(f'{edition} hierarchy not reproducible')
  extra=run([bindir/'vvp',tree,'+ntb_random_seed=1','+EXTRA_A'])
  if t1[0] or extra[0] or t1[1] != extra[1]:
   raise SystemExit(f'{edition} sibling stream changed after extra object draw')
  t2=run([bindir/'vvp',tree,'+ntb_random_seed=2'])
  if t2[0] or t1[1] == t2[1] or t1[1].split('override ')[1] != t2[1].split('override ')[1]:
   raise SystemExit(f'{edition} root/override distinction failed')
  for args in (['+ntb_random_seed='],['+ntb_random_seed=-1'],
               ['+ntb_random_seed=+1'],['+ntb_random_seed= 1'],
               ['+ntb_random_seed=1 '],['+ntb_random_seed=1x'],
               ['+ntb_random_seed=0x1'],['+ntb_random_seed=4294967296'],
               ['+ntb_random_seed=1','+ntb_random_seed=1'],
               ['+ntb_random_seed=1','+ntb_random_seed=2']):
   rc,so,se=run([bindir/'vvp',basic,*args])
   if (rc == 0 or 'ERROR: invalid +ntb_random_seed:' not in se
       or 'seed=' in so or 'tree ' in so):
    raise SystemExit(f'{edition} invalid seed accepted: {args}: {(rc,so,se)}')
print('PASSED')
