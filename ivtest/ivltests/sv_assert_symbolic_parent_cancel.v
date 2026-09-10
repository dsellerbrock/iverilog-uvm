// IEEE 16.12 and 16.15: cancellation clears mature parents and pending
// children; Off only prevents starts and lets old parents reach closure.
module parent_cancel_checker #(parameter LO=1)(input clk,keep,q,reset);
 integer p=0,f=0;
 assert property (@(posedge clk) disable iff(reset) keep[*LO:$] |-> ##1 q)
  p++; else f++;
endmodule
module sv_assert_symbolic_parent_cancel;
 reg clk=0,keep=1,q=1,reset=0,nba=0;
 parent_cancel_checker dut(clk,keep,q,reset);
 always @(posedge clk) if(nba) reset<=1;
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);
  q=0;#1 reset=1;#1 reset=0;tick();
  if(dut.p || dut.f) $fatal(1,"async mature cancellation");
  q=1;$asserton(0);tick();$assertoff(0);$assertkill(0);
  q=0;tick();
  if(dut.p || dut.f) $fatal(1,"killed mature parent resurrected");
  q=1;$asserton(0);tick();$assertoff(0);tick();
  if(dut.p || dut.f) $fatal(1,"Off prematurely closed parent");
  keep=0;tick();
  if(dut.p!=1 || dut.f) $fatal(1,"Off did not preserve mature parent");
  keep=1;$asserton(0);tick();$assertoff(0);
  q=0;nba=1;tick();nba=0;reset=0;keep=0;tick();
  if(dut.p!=1 || dut.f) $fatal(1,"NBA mature cancellation");
  $display("PASSED");
 end
endmodule
