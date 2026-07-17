// M12B: concurrent-assertion VPI object model. Three concurrent
// assertions are enumerated through vpi_iterate(vpiAssertion, ...).
module top;
  logic clk = 0, a = 1, b = 1;
  always #5 clk = ~clk;

  ap1: assert property (@(posedge clk) a |-> b);
  ap2: assert property (@(posedge clk) a ##1 b);
  ap3: assert property (@(posedge clk) a intersect b);

  initial begin
    #25 $check_assertions;
    $finish;
  end
endmodule
