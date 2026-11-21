`timescale 1ns/1ns

module issue3981_sequence_defaults;
  bit clk, b;
  int positional_hits, named_hits, override_hits;

  always #5 clk = !clk;

  sequence s(bit x=1, y=0);
    x ##1 y;
  endsequence

  cover property (@(posedge clk) s(,b)) begin
    if ($time != 15) $fatal(1, "Positional default matched at %0t", $time);
    positional_hits++;
  end
  cover property (@(posedge clk) s(.x(), .y(b))) begin
    if ($time != 15) $fatal(1, "Named default matched at %0t", $time);
    named_hits++;
  end
  cover property (@(posedge clk) s(1'b0, b)) override_hits++;

  initial begin
    #10 b = 1;
    #10 b = 0;
    #20;
    if (positional_hits != 1 || named_hits != 1 || override_hits != 0)
      $fatal(1, "Unexpected hit counts: positional=%0d named=%0d override=%0d",
             positional_hits, named_hits, override_hits);
    $display("PASSED");
    $finish(0);
  end
endmodule
