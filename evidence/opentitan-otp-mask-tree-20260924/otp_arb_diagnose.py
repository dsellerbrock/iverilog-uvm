from pathlib import Path
src=Path('/tmp/ot-otp-class-identity-20260924/otp_final.vvp')
dst=Path('/tmp/otp_arb_diagnose.vvp')
sigs={
 'u_edn_arb':('v0x7559bd2da0_0','v0x7559bd2d60_0','v0x7559bd2d20_0'),
 'u_otp_arb':('v0x7559166360_0','v0x7559166320_0','v0x75591662e0_0'),
 'u_req_arb':('v0x75591e0a00_0','v0x75591e09c0_0','v0x75591e0980_0'),
 'u_scrmbl_mtx':('v0x755921baa0_0','v0x755921ba60_0','v0x755921ba20_0'),
}
scopes={}
current_scope=None
armed=False
injections=[]
with src.open() as inp,dst.open('w') as out:
 for line in inp:
  if line.startswith('S_') and '.scope module, "' in line:
   for name in sigs:
    if f'"{name}" "prim_arbiter_tree"' in line: scopes[line.split()[0]]=name
  elif line.startswith('    .scope S_'):
   current_scope=scopes.get(line.split()[1].rstrip(';'))
  if '    %pushi/str "GrantKnown_A";' in line and current_scope in sigs:
   armed=True
  if armed and '    %callf/void TD_uvm_pkg.uvm_report_error' in line:
   if current_scope not in sigs: raise RuntimeError(f'unknown scope at report: {current_scope}')
   req,ready,gnt=sigs[current_scope]
   out.write(f'    %vpi_call/w 336 206 "$display", "OTP_ARB_FAIL %m req=%b ready=%b gnt=%b", {req}, {ready}, {gnt} {{0 0 0 0}};\n')
   if current_scope=='u_otp_arb':
    out.write('    %vpi_call/w 336 206 "$display", "OTP_ARB_DIRECT root_mask=%b mask_bit1=%b mask_d=%b root_sel=%b", L_0x7559316600, L_0x7558ed8850, v0x7559163be0_0, L_0x75593165c8 {0 0 0 0};\n')
    out.write('    %vpi_call/w 336 206 "$display", "OTP_ARB_TREE mask_q=%b req_tree=%b prio_tree=%b sel_tree=%b mask_tree=%b", v0x7559163c00_0, v0x7559163c40_0, v0x7559163c20_0, v0x7559163c60_0, v0x7559163bc0_0 {0 0 0 0};\n')
   injections.append(current_scope)
   armed=False
  out.write(line)
assert sorted(injections)==sorted(sigs),injections
print(dst, injections)
