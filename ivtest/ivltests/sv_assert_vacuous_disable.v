// disable iff is unsampled and asynchronous (IEEE 1800 16.12).
module disable_nba_driver;
 parameter LO=2,HI=3;
 reg clk=0,never=0,dis=0;
 integer linear=0,nfa=0,rep=0,win=0,gen=0;
 always @(posedge clk) dis<=1;
 l: assert property (@(posedge clk) disable iff(dis) never |-> 1'b0) linear++;
 n: assert property (@(posedge clk) disable iff(dis) never |-> not (never[*2])) nfa++;
 r: assert property (@(posedge clk) disable iff(dis) never[*LO] |-> 1'b0) rep++;
 w: assert property (@(posedge clk) disable iff(dis) never ##1 never |-> ##[0:HI] 1'b0) win++;
 for(genvar delay=2;delay<=2;delay++) begin:G
  g: assert property (@(posedge clk) disable iff(dis) never |-> ##delay 1'b0) gen++;
 end
 initial begin
  #5 clk=1;#1;
  if(linear || nfa || rep || win || gen) $fatal(1,"disabled counts=%0d/%0d/%0d/%0d/%0d",linear,nfa,rep,win,gen);
  ;
 end
endmodule

module disable_pulse_driver #(parameter logic [1:0] PULSE=2'b10, parameter bit CANCEL=1);
 reg clk=0,a=1,b=0;
 reg [1:0] dis=0;
 parameter LO=2,HI=3;
 integer linear=0,nfa=0,gen=0,failures=0,rep=0,win=0;
 l: assert property (@(posedge clk) disable iff(dis) a ##2 b |-> 1'b0) linear++; else failures++;
 n: assert property (@(posedge clk) disable iff(dis) a ##2 b |-> not (b[*2])) nfa++; else failures++;
 for(genvar delay=2;delay<=2;delay++) begin:G
  g: assert property (@(posedge clk) disable iff(dis) a |-> ##delay b) gen++; else failures++;
 end
 r: assert property (@(posedge clk) disable iff(dis) a[*LO] |-> b) rep++; else failures++;
 w: assert property (@(posedge clk) disable iff(dis) a ##2 b |-> ##[0:HI] b) win++; else failures++;
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();dis=PULSE;#1;dis=0;a=0;
  tick();tick();
  if(linear!=(CANCEL?2:3) || nfa!=(CANCEL?2:3) || gen!=2
     || rep!=(CANCEL?2:3) || win!=(CANCEL?2:3) || failures!=(CANCEL?0:1))
   $fatal(1,"pulse counts=%0d/%0d/%0d failures=%0d",linear,nfa,gen,failures);
  ;
 end
endmodule

module sv_assert_vacuous_disable;
 disable_nba_driver nba();
 disable_pulse_driver pulse();
 disable_pulse_driver #(2'b1x) pulse_known_one_x();
 disable_pulse_driver #(2'b0x,0) pulse_unknown_only();
 initial begin #20; $display("PASSED"); end
endmodule
