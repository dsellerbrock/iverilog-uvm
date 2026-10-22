from pathlib import Path
out = Path('tests/1800_audit/c20/m')
common = "logic [7:0] v8=8'b1x0z_1100; logic [15:0] big=16'h0100; logic [3:0] ctl;"
rows = [
 ('clog0','','','$clog2(0)','%0d','0'), ('clog1','','','$clog2(1)','%0d','0'),
 ('clog3','','','$clog2(3)','%0d','2'), ('clog1025','','','$clog2(1025)','%0d','11'),
 ('clogwide','','',"$clog2(64'h1_0000_0000)",'%0d','32'), ('clogbig','','','$clog2(big)','%0d','8'),
 ('sqrt','','','$sqrt(9.0)','%f','3.0'), ('pow','','','$pow(2.0,10.0)','%f','1024.0'),
 ('floorneg','','','$floor(-2.1)','%f','-3.0'), ('ceilneg','','','$ceil(-2.7)','%f','-2.0'),
 ('atan2','','','$atan2(1.0,1.0)','%f','0.785398'), ('hypot','','','$hypot(3.0,4.0)','%f','5.0'),
 ('tanh','','','$tanh(0.0)','%f','0.0'), ('acosh','','','$acosh(1.0)','%f','0.0'),
 ('cb1','','',"$countbits(v8,'1)",'%0d','3'), ('cb2','','',"$countbits(v8,'1,'0)",'%0d','6'),
 ('cb3','','',"$countbits(v8,'x,'z)",'%0d','2'), ('cb4','','',"$countbits(v8,'x,'x,'z)",'%0d','2'),
 ('cbvar','',"ctl[0]=1'bx; ctl[1]=1'bz;",'$countbits(v8,ctl[0],ctl[1])','%0d','2'),
 ('co1','','','$countones(v8)','%0d','3'), ('co2','','',"$countones(8'b1111_0000)",'%0d','4'),
 ('oh1','','',"$onehot(8'b0001_0000)",'%b','1'), ('oh2','','',"$onehot(8'b0011_0000)",'%b','0'),
 ('ohvar','','','$onehot(v8)','%b','0'), ('oh0a','','',"$onehot0(8'b0)",'%b','1'),
 ('oh0b','','',"$onehot0(8'b0110_0000)",'%b','0'), ('isu1','','','$isunknown(v8)','%b','1'),
 ('isu2','','',"$isunknown(8'hA5)",'%b','0'), ('onehotx','','',"$onehot(8'b0x01_0000)",'%b','1'),
 ('bitsof','','',"$bits($countbits(v8,'1))",'%0d','32'),
]
assert len(rows) == 30
for name, extra_decl, setup, expr, fmt, expected in rows:
    src = f'module m; {common} {extra_decl}\ninitial begin {setup} $display("Q {name}={fmt} exp {expected}", {expr}); end endmodule\n'
    (out / f'm_{name}.sv').write_text(src)
print(f'generated {len(rows)} independent expressions')
