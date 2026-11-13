checker issue2907_override_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s) else $display("override fail at %0t", $time);
endchecker
module issue2907_override;
  logic clk = 0, s = 1;
  always #5 clk = ~clk;
  issue2907_override_c u(.s(s), .clock(negedge clk));
  initial begin #12 s = 0; #10 $display("override done"); $finish; end
endmodule
