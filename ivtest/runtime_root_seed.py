#!/usr/bin/env python3
"""Focused reproducibility check for +ntb_random_seed."""
import os, pathlib, subprocess, sys, tempfile, re
root=pathlib.Path(__file__).resolve().parents[1]
bindir=root/'local-install/bin'
ivl=os.environ.get('IVERILOG', str(bindir/'iverilog'))
vvp=os.environ.get('VVP', str(bindir/'vvp'))
def run(cmd):
 p=subprocess.run([str(x) for x in cmd],text=True,capture_output=True,timeout=15)
 return p.returncode,p.stdout,p.stderr
def generated_words(result):
 words = result[1].split()
 if result[0] or len(words) != 5 or not all(re.fullmatch(r'[0-9a-fA-F]{8}', w) for w in words[1:]):
  raise SystemExit(f'invalid random payload: {result}')
 return words[1:]
with tempfile.TemporaryDirectory(prefix='ivl-root-seed-') as td:
 td=pathlib.Path(td)
 for edition in ('2017','2023'):
  basic=td/f'basic-{edition}.vvp'; tree=td/f'tree-{edition}.vvp'; threadless=td/f'threadless-{edition}.vvp'
  for out,name in ((basic,'sv_runtime_root_seed'),(tree,'sv_runtime_root_seed_hierarchy')):
   rc,so,se=run([ivl,f'-g{edition}','-s','test','-o',out,
                 root/'ivtest/ivltests'/f'{name}.v'])
   if rc: raise SystemExit(f'{edition} compile failed: {se}')
  rc,so,se=run([ivl,f'-g{edition}','-s','test','-o',threadless, root/'ivtest/ivltests'/'sv_runtime_root_seed_threadless.v'])
  if rc: raise SystemExit(f'{edition} threadless compile failed: {se}')
  default=run([vvp,basic])
  if default[:2] != (0,'seed=-1 70eedf01 04ae5bd4 a939a196 ab9d557b\n'):
   raise SystemExit(f'{edition} default sequence changed: {default}')
  one=run([vvp,basic,'+ntb_random_seed=1'])
  if one != run([vvp,basic,'+ntb_random_seed=1']):
   raise SystemExit(f'{edition} same seed not reproducible')
  if one != run([vvp,'+ntb_random_seed=1',basic]):
   raise SystemExit(f'{edition} seed argument position changed its meaning')
  two=run([vvp,basic,'+ntb_random_seed=2'])
  if one[0] or two[0] or generated_words(one) == generated_words(two):
   raise SystemExit(f'{edition} distinct seeds do not differ')
  for boundary,display in (('0','0'),('4294967295','-1')):
   rc,so,se=run([vvp,basic,f'+ntb_random_seed={boundary}'])
   if rc or not so.startswith(f'seed={display} '):
    raise SystemExit(f'{edition} valid boundary seed failed: {boundary}: {(rc,so,se)}')
  t1=run([vvp,tree,'+ntb_random_seed=1'])
  if t1 != run([vvp,tree,'+ntb_random_seed=1']):
   raise SystemExit(f'{edition} hierarchy not reproducible')
  extra=run([vvp,tree,'+ntb_random_seed=1','+EXTRA_A'])
  if t1[0] or extra[0] or t1[1] != extra[1]:
   raise SystemExit(f'{edition} sibling stream changed after extra object draw')
  t2=run([vvp,tree,'+ntb_random_seed=2'])
  if t2[0] or t1[1] == t2[1] or t1[1].split('override ')[1] != t2[1].split('override ')[1]:
   raise SystemExit(f'{edition} root/override distinction failed')
  for args in (['+ntb_random_seed='],['+ntb_random_seed=-1'],
               ['+ntb_random_seed=+1'],['+ntb_random_seed= 1'],
               ['+ntb_random_seed=1 '],['+ntb_random_seed=1x'],
               ['+ntb_random_seed=0x1'],['+ntb_random_seed=4294967296'],
               ['+ntb_random_seed=1','+ntb_random_seed=1'],
               ['+ntb_random_seed=1','+ntb_random_seed=2']):
   rc,so,se=run([vvp,basic,*args])
   if (rc == 0 or 'ERROR: invalid +ntb_random_seed:' not in se
       or 'seed=' in so or 'tree ' in so):
    raise SystemExit(f'{edition} invalid seed accepted: {args}: {(rc,so,se)}')
  for args in ([], ['+ntb_random_seed=0'], ['+ntb_random_seed=1'], ['+ntb_random_seed=4294967295']):
   rc,so,se=run([vvp,threadless,*args])
   if rc: raise SystemExit(f'{edition} valid threadless seed rejected: {(rc,so,se)}')
  for args in (['+ntb_random_seed=invalid'], ['+ntb_random_seed=1','+ntb_random_seed=2']):
   rc,so,se=run([vvp,threadless,*args])
   if rc == 0 or 'ERROR: invalid +ntb_random_seed:' not in se:
    raise SystemExit(f'{edition} threadless invalid seed accepted: {args}: {(rc,so,se)}')
print('PASSED')
