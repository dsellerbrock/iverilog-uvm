`timescale 1ns/1ps
interface unpacked_net_if(input logic clk);
  wire [7:0] data [0:1];
  logic other_enable = 0;
  logic [7:0] other_data = 8'hff;
  assign data[0] = other_enable ? other_data : 8'hzz;
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface

module sv_clocking_unpacked_net_output;
  logic clk = 0;
  always #5 clk = ~clk;
  unpacked_net_if bus(clk);
  bit failed = 0;

  initial begin
    #1;
    if (bus.data[0] !== 8'hzz || bus.data[1] !== 8'hzz) begin
      $display("FAILED unpacked net drivers were not initialized to Z");
      failed = 1;
    end
    bus.cb.data[0] <= 8'h00;
    bus.cb.data[1] <= 8'ha5;
    @(posedge clk);
    #1;
    if (bus.data[0] !== 8'h00 || bus.data[1] !== 8'ha5) begin
      $display("FAILED unpacked clocking output drive: %h %h",
               bus.data[0], bus.data[1]);
      failed = 1;
    end
    bus.other_enable = 1;
    #1;
    if (bus.data[0] !== 8'hxx || bus.data[1] !== 8'ha5) begin
      $display("FAILED independent unpacked net driver resolution: %h %h",
               bus.data[0], bus.data[1]);
      failed = 1;
    end
    if (!failed) $display("PASSED");
    $finish;
  end
endmodule
