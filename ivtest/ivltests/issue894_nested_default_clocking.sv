`timescale 1ns/1ps

module outer #(parameter int FIRST_EDGE = 5);
  bit clk, local_clk;
  bit nba_done, inherited_done, local_done;

  initial begin
    #(FIRST_EDGE);
    nba_done <= 1;
    clk = 1;
    #3 local_clk = 1;
  end

  default clocking cb @(posedge clk); endclocking

  module inherits_default;
    // This same-named block is not the default and never fires.
    clocking cb @(negedge clk); endclocking

    initial begin
      ##1;
      if ($time != FIRST_EDGE || !nba_done)
        $fatal(1, "inherited ##1 used the wrong event at %0t", $time);
      ##0 inherited_done = 1;
      if ($time != FIRST_EDGE)
        $fatal(1, "inherited ##0 waited again at %0t", $time);
    end
  endmodule
  inherits_default use_outer();

  module overrides_default;
    default clocking cb @(posedge local_clk); endclocking

    initial begin
      int cycles;
      cycles = 1;
      ##(cycles) local_done = 1;
      if ($time != FIRST_EDGE + 3)
        $fatal(1, "nested default did not take precedence at %0t", $time);
    end
  endmodule
  overrides_default use_local();
endmodule

module top;
  outer #(5) first();
  outer #(7) second();

  initial begin
    #20;
    if (!(first.inherited_done && first.local_done &&
          second.inherited_done && second.local_done))
      $fatal(1, "nested cycle delay did not complete");
    $display("NESTED_DEFAULT_CLOCKING_PASS");
  end
endmodule
