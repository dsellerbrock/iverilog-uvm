`timescale 1ns/1ps
module sv_assert_first_match_match_item;
  logic clk = 0;
  int hits = 0;
  always #5 clk = !clk;

  task automatic hit();
    hits++;
  endtask

  property local_property;
    // The match-item target is declared in its enclosing property scope.
    int local_value;
    first_match(1'b1, local_value = 1) |-> (local_value == 1);
  endproperty

  cover property (@(posedge clk) local_property);
  cover property (@(posedge clk) first_match(1'b1, hit()));

  initial begin
    repeat (3) @(posedge clk);
    #1;
    if (hits != 3) $fatal(1, "first_match call count=%0d", hits);
    $display("PASSED");
    $finish(0);
  end
endmodule
