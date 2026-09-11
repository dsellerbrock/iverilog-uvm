class holder;
 logic signed [7:0] values[string];
 function void update(); values["inner"] %= 2; endfunction
endclass
module test;
 logic signed [7:0] s[int];
 logic [7:0] u[int];
 bit [7:0] b[int];
 real reals[int];
 holder h;
 initial begin
  s[0]=-65; s[0]/=2; $display("signed_div=%0d",s[0]);
  s[1]=-65; s[1]%=2; $display("signed_mod=%0d",s[1]);
  s[2]=-64; s[2]>>>=32'd2; $display("ashift=%0d",s[2]);
  s[3]=-64; s[3]/=32'd2; $display("mixed=%0d",s[3]);
  s[4]=-64; s[4]/=32'sd257; $display("wide_signed=%0d",s[4]);
  u[0]=128; u[0]/=32'd257; $display("wide_unsigned=%0d",u[0]);
  u[1]=128; u[1]>>=32'd256; $display("wide_shift=%0d",u[1]);
  b[0]=42; b[0]+=32'hx; $display("bit_x=%0d",b[0]);
  u[2]=42; u[2]+=32'hx; $display("logic_x=%h",u[2]);
  if(s[0]!==-32 || s[1]!==-1 || s[2]!==-16 || s[3]!==96 || s[4]!==0 || u[0]!==0 || u[1]!==0 || b[0]!==0 || u[2]!==8'hxx)
   $fatal(1,"typing mismatch");
  h=new;
  h.values["outer"]=-65; h.values["outer"] /= 2;
  h.values["inner"]=-65; h.update();
  if(h.values["outer"]!==-32 || h.values["inner"]!==-1) $fatal(1,"property typing");
  s[5]=-64; s[5][7:0] /= 2;
  if(s[5]!==96) $fatal(1,"unsigned selection");
  reals[0]=7.5; reals[0]/=2.0;
  if(reals[0]!=3.75) $fatal(1,"real neighbor");
  $display("PASSED");
 end
endmodule
