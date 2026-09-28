`timescale 1ns/1ps
interface ibex_match_if(input logic clk);
  logic valid = 0;
  logic ready = 0;
  logic arm = 0;
  logic done = 0;
  int match_count = 0;
  int ordered_count = 0;
  int overlap_count = 0;
  logic reactive_marker = 0;
  always @(negedge clk) reactive_marker = 0;
  always @(posedge clk) reactive_marker <= 1;

  sequence cancelled_valid;
    @(posedge clk) (valid & ~ready) ##1
      (~valid, cover_cancelled_valid(), check_order(), $display("MATCH"));
  endsequence
  cover property (cancelled_valid);

  function automatic void cover_cancelled_valid();
    if (reactive_marker !== 1) $fatal(1, "match item ran before Reactive");
    match_count++;
  endfunction

  function automatic void check_order();
    ordered_count++;
    if (ordered_count != match_count) $fatal(1, "match calls out of source order");
  endfunction

  // Fixed-length starts overlap but end on successive sampled edges. The
  // first delayed task remains active when the second endpoint is checked.
  sequence overlapping;
    @(posedge clk) arm ##1 (done, overlap_hit());
  endsequence
  cover property (overlapping);

  task automatic overlap_hit();
    #12;
    overlap_count++;
  endtask
endinterface

module sv_sva_cover_match_item_runtime;
  logic clk = 0;
  always #5 clk = !clk;
  ibex_match_if pins(clk);

  initial begin
    @(negedge clk); pins.valid = 1; // start at the 15 ns posedge
    @(negedge clk); pins.valid = 0; // match at the 25 ns posedge
    @(posedge clk);
    #1;
    if (pins.match_count != 1) $fatal(1, "first match count=%0d", pins.match_count);
    @(negedge clk); pins.valid = 0; // no new match
    #1;
    if (pins.match_count != 1) $fatal(1, "no-match count=%0d", pins.match_count);
    @(negedge clk); pins.valid = 1; pins.arm = 1; // start at 45 ns
    @(negedge clk); pins.valid = 1; pins.arm = 1; pins.done = 1; // first endpoint at 55 ns
    @(negedge clk); pins.valid = 0; pins.arm = 0; pins.done = 1; // second endpoint at 65 ns
    @(posedge clk);
    #1;
    if (pins.match_count != 2) $fatal(1, "overlap count=%0d", pins.match_count);
    if (pins.overlap_count != 0) $fatal(1, "task blocked checker count=%0d", pins.overlap_count);
    #6;
    if (pins.overlap_count != 1) $fatal(1, "first delayed task count=%0d", pins.overlap_count);
    #10;
    if (pins.overlap_count != 2) $fatal(1, "overlap endpoints=%0d", pins.overlap_count);
    @(negedge clk); pins.valid = 0; pins.done = 0;
    #1;
    if (pins.match_count != 2) $fatal(1, "final count=%0d", pins.match_count);
    if (pins.ordered_count != 2) $fatal(1, "final ordered count=%0d", pins.ordered_count);
    if (pins.overlap_count != 2) $fatal(1, "final overlap count=%0d", pins.overlap_count);
    $display("PASSED");
    $finish(0);
  end
endmodule
