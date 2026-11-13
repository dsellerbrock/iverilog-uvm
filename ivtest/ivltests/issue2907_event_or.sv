checker issue2907_event_or_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s) else $display("event at %0t", $time);
endchecker
module issue2907_event_or;
  logic clk = 0, reset = 1, s = 0;
  always #5 clk = ~clk;
  default clocking @(posedge clk or negedge reset); endclocking
  issue2907_event_or_c u(.s(s), .clock());
  initial begin #7 reset = 0; #5 s = 1; #5 $display("event-or done"); $finish; end
endmodule
