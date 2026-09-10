// Empty |=> starts now; a nonempty match starts its consequent next tick.
module delay_empty_checker #(parameter N=0,D=0)(input clk,keep,q);
 integer p=0,f=0;
 assert property (@(posedge clk) keep[*N] |=> ##D q) p++; else f++;
endmodule
module sv_assert_cycle_delay_empty;
 reg clk=0,keep=1,q=1;
 delay_empty_checker empty_now(clk,keep,q);
 delay_empty_checker #(.N(1)) full_now(clk,keep,q);
 delay_empty_checker #(.D(8)) empty_late(clk,1'b0,q);
 delay_empty_checker #(.N(1),.D(8)) full_late(clk,keep,q);
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);
  if(empty_now.p!=1 || empty_now.f || full_now.p || full_now.f || empty_late.p || full_late.p)
   $fatal(1,"empty immediate child timing");
  q=0;tick();
  if(full_now.p || full_now.f!=1 || empty_late.p || empty_late.f || full_late.p || full_late.f)
   $fatal(1,"nonempty next-tick timing");
  q=1;repeat(7) tick();
  if(empty_late.p!=1 || empty_late.f || full_late.p || full_late.f)
   $fatal(1,"empty delayed child timing");
  q=0;tick();
  if(full_late.p || full_late.f!=1) $fatal(1,"nonempty delayed child timing");
  $display("PASSED");
 end
endmodule
