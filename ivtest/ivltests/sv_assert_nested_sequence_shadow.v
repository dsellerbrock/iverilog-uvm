module sv_assert_nested_sequence_shadow;
 reg clk=0,a=1,b=0;integer p=0,f=0;
 sequence Pair(x,y); x ##2 y; endsequence
 sequence Alias; Pair(a,b); endsequence
 if(1) begin:g
  sequence Pair(x,y); x ##1 y; endsequence
  assert property (@(posedge clk) Alias |-> 1'b1) p++; else f++;
 end
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin tick();$assertoff(0);a=0;tick();
 if(p||f)$fatal(1,"nested alias rebound to caller Pair");
 b=1;tick();if(p!=1||f)$fatal(1,"declaration Pair not used");$display("PASSED");end
endmodule
