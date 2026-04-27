// sva_default_test.sv — verify SV `default disable iff (...)` and
//   `default clocking ... endclocking` compile silently at module
//   scope. iverilog does not yet model concurrent-assertion semantics
//   so these are parsed and dropped.

module top;
  logic clk = 0;
  logic rst_n = 1;
  always #5 clk = ~clk;

  default disable iff (!rst_n);
  default clocking @(posedge clk); endclocking

  initial begin
    #50 $display("PASS sva_default compiled and ran");
    $finish;
  end
endmodule
