// IEEE 1800-2017/2023 16.12.7, 16.14.1: one verdict per parent.
module check #(parameter LO=2,HI=3)(input clk,a,q);
 integer passes=0,failures=0;
 p: assert property (@(posedge clk) a[*LO:HI] |-> q) passes++; else failures++;
endmodule
module sv_assert_symbolic_parent_verdict;
 reg clk=0,a=1;
 check good(clk,a,1'b1);
 check bad(clk,a,1'b0);
 integer early=0;
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);
  tick();
  $display("early good=%0d/%0d bad=%0d/%0d",good.passes,good.failures,bad.passes,bad.failures);
  early=(good.passes!=0 || good.failures!=0 || bad.passes!=0 || bad.failures!=1);
  tick();
  $display("final good=%0d/%0d bad=%0d/%0d",good.passes,good.failures,bad.passes,bad.failures);
  if(early || good.passes!=1 || good.failures!=0 || bad.passes!=0 || bad.failures!=1)
   $fatal(1,"one verdict per starting implication attempt required");
  $display("PASSED");
 end
endmodule
