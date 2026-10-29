// IEEE 1800-2017/2023 16.12.22(c): a nonoverlapping antecedent may admit
// only empty matches. Keep the assertion and verify it evaluates its false
// consequent instead of silently dropping the property.
module issue1395_empty_only_nonoverlap;
 reg clk=0,b=0;
 integer failures=0;
 always #5 clk=~clk;
 assert property (@(posedge clk) 1'b1[*0] |=> b) ; else failures++;
 initial begin
  repeat(4) @(negedge clk);
  #1;
  if(failures==0) $fatal(1,"empty-only nonoverlapping implication was not evaluated");
  $display("empty-only-nonoverlap=legal");
  $finish(0);
 end
endmodule
