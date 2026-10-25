`timescale 1ns/1ps
module sv_assert_first_match_match_item;
  logic clk = 0;
  int hits = 0;
  always #5 clk = !clk;

  task automatic hit();
    hits++;
  endtask

  sequence local_sequence;
    int local_value;
    1'b1;
  endsequence

  cover property (@(posedge clk) first_match(local_sequence, local_value = 1));
  cover property (@(posedge clk) first_match(1'b1, hit()));

  initial begin
    repeat (3) @(posedge clk);
    #1;
    if (hits != 3) $fatal(1, "first_match call count=%0d", hits);
    $display("PASSED");
    $finish(0);
  end
endmodule
