// IEEE 1800-2017/2023 16.12.7, 16.14.1: one verdict per parent.
module bounded #(parameter LO=2, HI=3, D=0)(input clk,a,q);
 integer p=0,f=0;
 if(D) assert property (@(posedge clk) a[*LO:HI] |-> ##1 q) p++; else f++;
 else assert property (@(posedge clk) a[*LO:HI] |-> q) p++; else f++;
endmodule
module unbounded #(parameter LO=2, D=0)(input clk,a,q);
 integer p=0,f=0;
 if(D) assert property (@(posedge clk) a[*LO:$] |-> ##1 q) p++; else f++;
 else assert property (@(posedge clk) a[*LO:$] |-> q) p++; else f++;
endmodule
module prefixed #(parameter LO=0,HI=2,D=0)(input clk,a,q);
 integer p=0,f=0;
 if(D) assert property (@(posedge clk) 1'b1 ##1 a[*LO:HI] |-> ##1 q) p++; else f++;
 else assert property (@(posedge clk) 1'b1 ##1 a[*LO:HI] |-> q) p++; else f++;
endmodule
module sv_assert_symbolic_parent_boundaries;
 reg clk=0,a=1,q=1,lastq=1;
 bounded b(clk,a,q);
 bounded #(.D(1)) d(clk,a,q);
 bounded #(.D(1)) terminal(clk,a,lastq);
 unbounded u(clk,a,1'b1);
 unbounded #(.D(1)) ud(clk,a,1'b1);
 prefixed p(clk,a,q);
 prefixed #(.D(1)) pd(clk,a,q);
 integer errors=0;
 task tick; #5 clk=1; #1 clk=0; endtask
 initial begin
  tick(); $assertoff(0);
  if(p.p || pd.p) errors++;
  tick();
  if(b.p || d.p || terminal.p || u.p || ud.p || p.p || pd.p) errors++;
  q=1'bx; tick();
  if(b.f!=1 || d.f!=1 || p.f!=1 || pd.f!=1) errors++;
  if(b.p || d.p || terminal.p || u.p || ud.p || p.p || pd.p) errors++;
  a=1'bz;q=1;lastq=0;tick();
  if(b.f!=1 || d.f!=1 || terminal.f!=1 || p.f!=1 || pd.f!=1) errors++;
  if(b.p || d.p || terminal.p || p.p || pd.p || u.p!=1 || ud.p!=1 || u.f || ud.f) errors++;
  $display("errors=%0d bounded=%0d/%0d delayed=%0d/%0d terminal=%0d/%0d unbounded=%0d/%0d,%0d/%0d prefix=%0d/%0d,%0d/%0d",errors,b.p,b.f,d.p,d.f,terminal.p,terminal.f,u.p,u.f,ud.p,ud.f,p.p,p.f,pd.p,pd.f);
  if(errors) $fatal(1,"symbolic parent boundary mismatch");
  $display("PASSED");
 end
endmodule
