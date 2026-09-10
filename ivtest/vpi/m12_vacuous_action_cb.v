// Vacuous user actions never report cbAssertionSuccess. Reuse the callback
// counter plugin; the sole standalone true assertion supplies five successes.
module m12_vacuous_action_cb;
 parameter LO=2, HI=3;
 reg clk=0,never=0;
 integer linear=0,nfa=0,rep=0,win=0,tree=0,gen=0;
 sequence Left; never ##1 never; endsequence
 sequence Right; never ##1 never; endsequence
 l: assert property (@(posedge clk) never |-> 1'b0) linear++; else $fatal;
 n: assert property (@(posedge clk) never |-> not (never[*2])) begin #20; nfa++; end else $fatal;
 r: assert property (@(posedge clk) never[*LO] |-> 1'b0) rep++; else $fatal;
 w: assert property (@(posedge clk) never ##1 never |-> ##[0:HI] 1'b0) win++; else $fatal;
 t: assert property (@(posedge clk) Left or Right |-> ##[0:HI] 1'b0) tree++; else $fatal;
 for(genvar delay=2;delay<=2;delay++) begin:G
  g: assert property (@(posedge clk) never |-> ##delay 1'b0) gen++; else $fatal;
 end
 success: assert property (@(posedge clk) 1'b1);
 initial begin
  #1; $setup_endpoint_fanout_cb;
  repeat(5) begin #5 clk=1; #1 clk=0; end
  #25;
  if(linear!=5 || nfa!=5 || rep!=5 || win!=5 || tree!=5 || gen!=5)
   $fatal(1,"vacuous action counts %0d/%0d/%0d/%0d/%0d/%0d",linear,nfa,rep,win,tree,gen);
  $check_endpoint_fanout_cb(5,0);
 end
endmodule
