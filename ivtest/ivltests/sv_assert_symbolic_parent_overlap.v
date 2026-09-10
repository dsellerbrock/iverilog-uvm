// IEEE 1800-2017/2023 16.12.7, 16.14.1: one verdict per parent.
module check #(parameter LO=0,HI=2)(input clk,keep,q);
 integer p=0,f=0;
 assert property (@(posedge clk) 1'b1 ##1 keep[*LO:HI] |-> ##1 q) p++; else f++;
endmodule
module unbounded #(parameter LO=0)(input clk,keep,q);
 integer p=0,f=0;
 assert property (@(posedge clk) 1'b1 ##1 keep[*LO:$] |-> ##1 q) p++; else f++;
endmodule
module sv_assert_symbolic_parent_overlap;
 reg clk=0,keep=1,q=1;
 check dut(clk,keep,q);
 unbounded uncapped(clk,keep,q);
 integer errors=0;
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();tick();q=0;tick();
  if(dut.p || dut.f!=2) errors++;
  q=1;tick();tick();
  if(dut.p || dut.f!=2) errors++;
  q=0;tick();$assertoff(0);
  if(dut.p || dut.f!=5) errors++;
  keep=0;q=1;tick();tick();
  if(dut.p!=1 || dut.f!=5) errors++;
  if(uncapped.p!=1 || uncapped.f!=5) errors++;
  $display("errors=%0d p/f=%0d/%0d",errors,dut.p,dut.f);
  if(errors) $fatal(1,"simultaneous parent retirement and new prefix");
  $display("PASSED");
 end
endmodule
