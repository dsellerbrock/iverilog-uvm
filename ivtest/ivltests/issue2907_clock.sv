checker issue2907_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s) else $display("q04 fail at %0t", $time);
endchecker
module issue2907_clock_case;
  logic clk = 0, s = 1;
  always #5 clk = ~clk;
  default clocking @(posedge clk); endclocking
  issue2907_c u(s);
  initial begin #12 s = 0; #10 $display("q04 done");  end
endmodule

checker issue2907_override_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s) else $display("override fail at %0t", $time);
endchecker
module issue2907_override;
  logic clk = 0, s = 1;
  always #5 clk = ~clk;
  issue2907_override_c u(.s(s), .clock(negedge clk));
  initial begin #12 s = 0; #10 $display("override done");  end
endmodule

checker issue2907_event_or_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s) else $display("event at %0t", $time);
endchecker
module issue2907_event_or;
  logic clk = 0, reset = 1, s = 0;
  always #5 clk = ~clk;
  default clocking @(posedge clk or negedge reset); endclocking
  issue2907_event_or_c u(.s(s), .clock());
  initial begin #7 reset = 0; #5 s = 1; #5 $display("event-or done");  end
endmodule

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
    #4 $display("guarded done");
  end
endmodule

module issue2907_clock;
  issue2907_clock_case a();
  issue2907_override b();
  issue2907_event_or c();
  issue2907_event_iff d();
  initial #23 $finish;
endmodule
