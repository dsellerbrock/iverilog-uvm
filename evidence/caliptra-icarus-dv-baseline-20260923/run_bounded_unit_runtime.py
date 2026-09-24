#!/usr/bin/env python3
"""Compile and run three selected bounded unit testbenches with current Icarus."""
import hashlib, json, os, shutil, subprocess, time
from pathlib import Path
ROOT=Path.cwd(); OUT=ROOT/'evidence/caliptra-icarus-dv-baseline-20260923'
CAL=Path('/Users/danielellerbrock/projects/iverilog_uvm/caliptra-rtl')
ABR=CAL/'submodules/adams-bridge'
OLD=ROOT/'evidence/caliptra-full-dv-unit-census-20260923/runtime'
ENV=os.environ.copy(); ENV.update(CALIPTRA_ROOT=str(CAL),CALIPTRA_PRIM_ROOT=str(CAL/'src/caliptra_prim_generic'),CALIPTRA_PRIM_MODULE_PREFIX='caliptra_prim_generic',ADAMSBRIDGE_ROOT=str(ABR))
I=ROOT/'local-install/bin/iverilog'; V=ROOT/'local-install/bin/vvp'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(argv,cwd,timeout):
 env=ENV.copy(); env['PATH']=str(cwd)+os.pathsep+env.get('PATH','')
 t=time.monotonic(); p=subprocess.run(argv,cwd=cwd,env=env,capture_output=True,text=True,timeout=timeout)
 return p,round(time.monotonic()-t,3)
rows=[]
for name in ['power2round_tb','rej_bounded_tb','csrng_tb']:
 d=OUT/'runtime'/name; d.mkdir(parents=True,exist_ok=True)
 plus=[]
 if name=='power2round_tb':
  vf=ABR/'src/power2round/config/power2round_tb.vf'; oldcwd=OLD/'power2round'
  for f in ['coeff_input.hex','coeff_high.hex','coeff_low.hex','power2round.py','python']:
   shutil.copy2(oldcwd/f,d/f)
  src_repo=ABR; top=name
 elif name=='rej_bounded_tb':
  vf=ABR/'src/rej_bounded/config/rej_bounded_tb.vf'; oldcwd=OLD/'rej_bounded_pristine'
  for f in ['input_seeds.txt','input_vectors.txt','exp_results.txt','rej_bounded.py','python']:
   shutil.copy2(oldcwd/f,d/f)
  plus=['+VEC_CNT=100']; src_repo=ABR; top=name
 else:
  vf=OUT/'runtime/csrng_tb/csrng_tb_package_first.vf'
  shutil.copy2(ROOT/'evidence/caliptra-csrng-header-closure-20260923/csrng_tb_package_first.vf',vf)
  # Match the reviewed disposable filelist corrections while keeping all pinned source intact.
  with vf.open('a') as f: f.write('+incdir+${CALIPTRA_ROOT}/src/integration/rtl/caliptra_reg\n')
  src_repo=CAL; top=name
 image=d/'design.vvp'
 compile_argv=[str(I),'-g2012','-gassertions','-s',top,'-o',str(image),'-f',str(vf)]
 c,ct=run(compile_argv,ROOT,120)
 (d/'compile.stdout.log').write_text(c.stdout); (d/'compile.stderr.log').write_text(c.stderr)
 row={'test':name,'pinned_repo_head':subprocess.check_output(['git','-C',str(src_repo),'rev-parse','HEAD'],text=True).strip(),'filelist':str(vf),'filelist_sha256':sha(vf),'compile_argv':compile_argv,'compile_exit_code':c.returncode,'compile_elapsed_seconds':ct,'compile_stdout':'compile.stdout.log','compile_stderr':'compile.stderr.log','compile_image_sha256':sha(image) if image.exists() else None,'stimulus_hashes':{p.name:sha(p) for p in d.iterdir() if p.is_file() and p.name not in ['design.vvp','compile.stdout.log','compile.stderr.log']},'plusargs':plus,'runtime_timeout_seconds':60}
 if c.returncode==0:
  argv=[str(V),str(image),*plus]
  r,rt=run(argv,d,60)
  (d/'runtime.stdout.log').write_text(r.stdout); (d/'runtime.stderr.log').write_text(r.stderr)
  row.update(runtime_argv=argv,runtime_exit_code=r.returncode,runtime_elapsed_seconds=rt,runtime_stdout='runtime.stdout.log',runtime_stderr='runtime.stderr.log',pass_markers=r.stdout.count('TESTCASE PASSED'),fail_markers=r.stdout.count('TESTCASE FAILED'),error_marker_count=sum(1 for line in (r.stdout+'\n'+r.stderr).splitlines() if 'error:' in line.lower() or 'fatal' in line.lower()))
  if r.returncode==0 and row['pass_markers']>0 and row['fail_markers']==0 and row['error_marker_count']==0: row['runtime_classification']='PASS'
  elif r.returncode==0 and row['fail_markers']>0: row['runtime_classification']='FAIL'
  else: row['runtime_classification']='BLOCKED'
 else: row['runtime_classification']='UNRUN_COMPILE_BLOCKED'
 rows.append(row)
 (OUT/'bounded-unit-runtime-results.json').write_text(json.dumps({'scope':'Fresh bounded Icarus unit-runtime checks; only explicit testbench verdict markers count as runtime pass.','compiler_sha256':sha(I),'vvp_sha256':sha(V),'entries':rows},indent=2)+'\n')
 print(name,row['runtime_classification'],row.get('runtime_exit_code'),row.get('pass_markers'),row.get('fail_markers'),flush=True)
