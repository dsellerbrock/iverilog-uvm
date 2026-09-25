`timescale 1ns/1ps

interface clocking_declaration_only_if(input logic clk);
  logic source, final_value;
  assign final_value = source;
  clocking sender_cb @(posedge clk);
    output final_value;
  endclocking
endinterface

module sv_clocking_output_continuous_declaration_only;
  logic clk = 0;
  clocking_declaration_only_if bus(clk);
  initial begin
    bus.source = 1'b1;
    #1;
    if (bus.final_value !== 1'b1)
      $fatal(1, "declaration-only clocking output changed final value");
    $display("PASSED");
    $finish;
  end
endmodule
