module sv_assert_nested_sequence_actual_scope;
 reg clk=0,a=1,b=1;integer p=0,r=0;
 sequence Local; a ##2 b; endsequence
 sequence Wrap(s); s; endsequence
 sequence Outer; Wrap(Local); endsequence
 if(1) begin:g
  sequence Local; a ##1 b; endsequence
  assert property (@(posedge clk) Outer |-> 1'b1) p++;
  assert property (@(posedge clk) Wrap(Local) |-> 1'b1) r++;
 end
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin tick();$assertoff(0);a=0;tick();
 if(p||r!=1)$fatal(1,"caller actual binding");
 tick();if(p!=1||r!=1)$fatal(1,"alias actual binding");$display("PASSED");end
endmodule
