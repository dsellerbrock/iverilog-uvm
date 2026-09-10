// IEEE 1800-2017/2023 16.12.7, 16.14.1: one verdict per parent.
module check #(parameter N=0,L=0,H=0)(input clk,a,q);
 integer p=0,f=0;
 assert property (@(posedge clk) a[*N] |=> ##[L:H] q) p++; else f++;
endmodule
module prefix #(parameter N=0,L=0,H=0)(input clk,a,q);
 integer p=0,f=0;
 assert property (@(posedge clk) a ##1 a[*N] |=> ##[L:H] q) p++; else f++;
endmodule
module sv_assert_symbolic_empty_window;
 reg clk=0,a=1,q=1;
 check direct(clk,a,q);
 prefix pref(clk,a,q);
 check #(.L(1),.H(1)) shifted(clk,a,q);
 check #(.N(1),.L(1),.H(1)) nonempty(clk,a,q);
 check false_keep(clk,1'b0,q);
 integer errors=0;
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);
  if(direct.p!=1 || direct.f || pref.p || pref.f) errors++;
  if(shifted.p || shifted.f || nonempty.p || nonempty.f || false_keep.p!=1 || false_keep.f) errors++;
  q=0;tick();
  if(shifted.p || shifted.f!=1 || nonempty.p || nonempty.f || false_keep.p!=1 || false_keep.f) errors++;
  if(direct.p!=1 || direct.f || pref.p || pref.f!=1) errors++;
  tick();
  if(shifted.p || shifted.f!=1 || nonempty.p || nonempty.f!=1) errors++;
  if(direct.p!=1 || direct.f || pref.p || pref.f!=1) errors++;
  $display("errors=%0d direct=%0d/%0d prefix=%0d/%0d",errors,direct.p,direct.f,pref.p,pref.f);
  if(errors) $fatal(1,"empty nonoverlapped start timing");
  $display("PASSED");
 end
endmodule
