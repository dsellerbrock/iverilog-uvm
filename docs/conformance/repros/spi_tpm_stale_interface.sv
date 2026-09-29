module current_tpm #(
  parameter int CmdAddrFifoDepth = 2,
  localparam int WrFifoDepth = 64
) (
  input logic clk,
  input logic [31:0] sys_rdfifo_wdata_i
);
endmodule

module bad_parameters;
  logic [31:0] d;
  current_tpm #(
    .WrFifoDepth(4),
    .RdDataFifoSize(8)
  ) dut (.clk(1'b0), .sys_rdfifo_wdata_i(d));
endmodule

module bad_port;
  logic [31:0] d;
  current_tpm dut (
    .clk(1'b0),
    .sys_wrfifo_rdata_o(d)
  );
endmodule

module current_connections;
  logic [31:0] d;
  current_tpm #(.CmdAddrFifoDepth(2)) dut (
    .clk(1'b0),
    .sys_rdfifo_wdata_i(d)
  );
endmodule
