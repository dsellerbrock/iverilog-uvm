`timescale 1ns/1ps

module top;
  import axi_pkg::*;

  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;
  axi_if bus(clk, rst_n);

  initial begin
    bus.arready = 1;
    bus.rvalid = 0;
    bus.rresp = AXI_RESP_OKAY;
    bus.rid = 0;
    bus.rlast = 0;
    #12 rst_n = 1;
    wait (bus.arvalid);
    wait (bus.rready);
    @(negedge clk);
    bus.rvalid = 1;
    bus.rdata = 32'h1234_5678;
    bus.ruser = 32'hdeaf_0001;
    @(negedge clk);
    bus.rdata = 32'h8765_4321;
    bus.ruser = 32'hdeaf_0002;
    bus.rlast = 1;
    @(negedge clk);
    bus.rvalid = 0;
  end

  initial begin
    logic [31:0] data[];
    logic [31:0] ruser[];
    axi_resp_e resp[];
    wait (rst_n);
    bus.axi_read(.addr(32'h100), .len(1), .data(data),
                 .resp_user(ruser), .resp(resp));
    if (data.size() != 2 || ruser.size() != 2 || resp.size() != 2)
      $fatal(1, "AXI read array lengths were not retained");
    if (data[0] !== 32'h1234_5678 || data[1] !== 32'h8765_4321)
      $fatal(1, "AXI read payload mismatch");
    if (ruser[0] !== 32'hdeaf_0001 || ruser[1] !== 32'hdeaf_0002)
      $fatal(1, "AXI RUSER payload mismatch");
    if (resp[0] != AXI_RESP_OKAY || resp[1] != AXI_RESP_OKAY)
      $fatal(1, "AXI read response mismatch");
    $display("PASS AXI_RUSER_READ");
    $finish;
  end

  initial begin
    #200;
    $fatal(1, "AXI read timed out");
  end
endmodule
