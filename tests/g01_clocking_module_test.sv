// G01/G02: clocking blocks allowed in modules and programs (IEEE 1800-2017 §14.3)
module top;
  logic clk;
  clocking cb @(posedge clk);
    input clk;
  endclocking
  initial begin
    $display("PROBE_OK_clocking_in_module");
    $finish;
  end
endmodule
