module test;
 reg trigger=0;
 wire tap=trigger;
 reg [1:0] value=2;
 int hits;
 initial begin
  #1;
  fork begin @(posedge(value[0] && value[1])); hits++; end join_none
  #1; $arm_atomic_callback; trigger=1;
  #1; if(hits!=1) $fatal(1,"callback-origin pulse lost hits=%0d",hits);
  $display("PASSED callback-origin source assignments");
 end
endmodule
