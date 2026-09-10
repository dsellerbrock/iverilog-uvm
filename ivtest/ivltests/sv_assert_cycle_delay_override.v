// IEEE 6.20.2,23.10.2,16.7: instance values determine every ##D tick.
module delay_override_checker #(parameter LO=1,HI=2,D=0)(input clk,keep,q);
 localparam DELAY=(D+1)-1;
 integer p=0,f=0;
 assert property (@(posedge clk) keep[*LO:HI] |-> ##DELAY q) p++; else f++;
endmodule
module sv_assert_cycle_delay_override;
 reg clk=0,keep=1,q=1;
 delay_override_checker zero(clk,keep,q);
 delay_override_checker #(1,2,1) one(clk,keep,q);
 delay_override_checker #(.D(8)) eight(clk,keep,q);
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);tick();
  if(zero.p!=1 || zero.f || one.p || one.f || eight.p || eight.f)
   $fatal(1,"overridden delay start timing");
  q=0;tick();
  if(one.p || one.f!=1 || eight.p || eight.f) $fatal(1,"delay-one last child");
  q=1;repeat(6) tick();
  if(eight.p || eight.f) $fatal(1,"delay-eight parent passed early");
  q=0;tick();keep=0;repeat(2) tick();
  if(zero.p!=1 || zero.f || one.p || one.f!=1 || eight.p || eight.f!=1)
   $fatal(1,"one verdict per delayed parent");
  $display("PASSED");
 end
endmodule
