// IEEE 1800-2017/2023 16.12.7, 16.14.1: one verdict per parent.
module check #(parameter LO=0,HI=2)(input clk,keep,q);
 integer p=0,f=0,up=0,uf=0;
 assert property (@(posedge clk) keep[*LO:HI] |-> q) p++; else f++;
 assert property (@(posedge clk) keep[*LO:$] |-> q) up++; else uf++;
endmodule
module sv_assert_symbolic_parent_zero_range;
 reg clk=0,keep=0,q=0;
 check dut(clk,keep,q);
 integer errors=0;
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);tick();
  if(dut.p!=1 || dut.f || dut.up!=1 || dut.uf) errors++;
  keep=1;q=1;$asserton(0);tick();$assertoff(0);
  if(dut.p!=1 || dut.f || dut.up!=1 || dut.uf) errors++;
  q=0;tick();keep=0;tick();
  if(dut.p!=1 || dut.f!=1 || dut.up!=1 || dut.uf!=1) errors++;
  $display("errors=%0d bounded=%0d/%0d unbounded=%0d/%0d",errors,dut.p,dut.f,dut.up,dut.uf);
  if(errors) $fatal(1,"overlapped implication uses nonempty matches");
  $display("PASSED");
 end
endmodule
