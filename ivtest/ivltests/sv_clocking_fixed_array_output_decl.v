`timescale 1ns/1ps
interface array_if(input logic clk);
  logic [7:0] source[2];
  logic [7:0] data[2];
  always begin data[0] = source[0]; data[1] = source[1]; @(source[0], source[1]); end
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface

module sv_clocking_fixed_array_output_decl;
  logic clk = 0;
  always #5 clk = ~clk;
  array_if bus(clk);
  initial begin
    bus.source[0] = 8'h12;
    bus.source[1] = 8'h34;
    #6;
    if (bus.data[0] !== 8'h12 || bus.data[1] !== 8'h34)
      $fatal(1, "array source loop failed");
    $display("PASSED");
    $finish;
  end
endmodule
