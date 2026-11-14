module main;
  bit clk = 0;
  always #5 clk = ~clk;

  // One pending single-cycle attempt and two pending indexed attempts.
  one: assert property (@(posedge clk) s_nexttime (1'b1))
    else $display("EOS failure action");
  indexed: assert property (@(posedge clk) s_nexttime[3] (1'b1))
    else $display("EOS failure action");
  weak_control: assert property (@(posedge clk) nexttime[3] (1'b1))
    else $display("unexpected weak failure");
  zero_control: assert property (@(posedge clk) s_nexttime[0] (1'b1))
    else $display("unexpected zero-delay failure");
  normal_control: assert property (@(posedge clk) s_nexttime (1'b0))
    else $display("normal failure action");

  initial begin #16; $finish(0); end
endmodule
