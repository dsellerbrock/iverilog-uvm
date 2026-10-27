`timescale 1ns/1ps
module test;
  logic clk = 0, a = 0, b = 0;
  time selected_time = 0;
  always #5 clk = ~clk;

  // The sequence has matches at both offsets; first_match's match item runs
  // only for the match with the earliest ending clock tick.
  cover property (@(posedge clk)
                  first_match(a ##[1:2] b, selected_time = $time));

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);

    if (selected_time != 25)
      $fatal(1, "§16.9.8 expected earliest match at 25, got %0t", selected_time);
    $display("PASSED: §16.9.8 first_match selected the earliest match at %0t",
             selected_time);
    $finish(0);
  end
endmodule
