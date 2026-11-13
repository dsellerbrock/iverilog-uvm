checker issue2907_event_iff_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s) else $display("guarded event at %0t", $time);
endchecker
module issue2907_event_iff;
  logic clk = 0, reset = 1, enable = 0, s = 0;
  always #5 clk = ~clk;
  default clocking @(posedge clk iff enable or negedge reset); endclocking
  issue2907_event_iff_c u(s);
  initial begin
    #7 reset = 0;
    #1 enable = 1;
    #10 s = 1;
    #4 $display("guarded done"); $finish;
  end
endmodule
