// Each eligible cover endpoint is checked at its elaborated delay.
module cover_delay_checker #(parameter LO=1,HI=3,D=0)(input clk,keep,q);
 cover property (@(posedge clk) keep[*LO:HI] |-> ##D q);
endmodule
module sv_cover_cycle_delay_override;
 reg clk=0,keep=1,q=1;
 cover_delay_checker now(clk,keep,q);
 cover_delay_checker #(.D(8)) late(clk,keep,q);
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);q=0;tick();q=1;tick();keep=0;
  if(now._ivl_sva0_cnt0!=2 || late._ivl_sva0_cnt0) $fatal(1,"cover point timing");
  repeat(6) tick();
  if(late._ivl_sva0_cnt0!=1) $fatal(1,"first delayed cover endpoint");
  q=0;tick();q=1;tick();
  if(now._ivl_sva0_cnt0!=2 || late._ivl_sva0_cnt0!=2)
   $fatal(1,"cover endpoints must survive other failed children");
  $display("PASSED");
 end
endmodule
