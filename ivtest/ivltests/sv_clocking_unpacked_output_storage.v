// Whole unpacked clockvar drives use the same synchronous schedule as packed
// clockvars and update every word.
interface clocking_unpacked_output_if(input logic clk);
  logic [7:0] raw [0:1];

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_unpacked_output_storage;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  clocking_unpacked_output_if bus(clk);

  initial begin
    bus.raw[0] = 8'h12;
    bus.raw[1] = 8'h34;
    #1 bus.cb.raw <= '{8'ha5, 8'h5a};
    @(posedge clk);
    #1;
    if (bus.raw[0] !== 8'ha5 || bus.raw[1] !== 8'h5a)
      $fatal(1, "whole-array clocking drive was not applied at the event");
    $display("PASSED");
    $finish;
  end
endmodule
