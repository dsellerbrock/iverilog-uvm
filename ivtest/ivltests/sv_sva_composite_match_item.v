module sv_sva_composite_match_item;
  logic clk = 0;
  logic a = 1;
  logic b = 0;
  always #5 clk = ~clk;

  sequence delayed_assignment;
    int value;
    ((a ##1 b), value = 7) ##1 (value == 7);
  endsequence

  assert property (@(posedge clk) (a && !b) |-> delayed_assignment)
    else $fatal(1, "composite sequence match item failed");

  initial begin
    @(negedge clk);
    b = 1;
    repeat (3) @(negedge clk);
    $display("PASSED");
    $finish;
  end
endmodule
