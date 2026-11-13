checker issue2907_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s) else $display("q04 fail at %0t", $time);
endchecker
module issue2907_clock;
  logic clk = 0, s = 1;
  always #5 clk = ~clk;
  default clocking @(posedge clk); endclocking
  issue2907_c u(s);
  initial begin #12 s = 0; #10 $display("q04 done"); $finish; end
endmodule
