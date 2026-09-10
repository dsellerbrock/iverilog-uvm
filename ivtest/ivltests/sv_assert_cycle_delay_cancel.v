// Cancellation must discard captured starts even before replay begins.
module delay_cancel_checker #(parameter LO=1,D=8)(input clk,keep,q,reset);
 integer p=0,f=0;
 assert property (@(posedge clk) disable iff(reset) keep[*LO:$] |-> ##D q) p++; else f++;
endmodule
module sv_assert_cycle_delay_cancel;
 reg clk=0,keep=1,q=1,reset=0,nba=0;
 delay_cancel_checker dut(clk,keep,q,reset);
 always @(posedge clk) if(nba) reset<=1;
 task tick;#5 clk=1;#1 clk=0;endtask
 task drain;keep=0;q=0;repeat(10) tick();endtask
 initial begin
  tick();$assertoff(0);#1 reset=1;#1 reset=0;drain();
  if(dut.p || dut.f) $fatal(1,"async canceled history resurrected");
  keep=1;q=1;$asserton(0);tick();$assertoff(0);$assertkill(0);drain();
  if(dut.p || dut.f) $fatal(1,"killed history resurrected");
  keep=1;q=1;$asserton(0);tick();$assertoff(0);nba=1;tick();
  nba=0;reset=0;drain();
  if(dut.p || dut.f) $fatal(1,"NBA canceled history resurrected");
  keep=1;q=1;$asserton(0);tick();$assertoff(0);keep=0;
  repeat(7) tick();
  if(dut.p || dut.f) $fatal(1,"delayed parent passed before child");
  tick();
  if(dut.p!=1 || dut.f) $fatal(1,"Off lost a captured start");
  $display("PASSED");
 end
endmodule
