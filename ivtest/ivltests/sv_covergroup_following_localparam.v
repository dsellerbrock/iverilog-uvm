interface cov_if(input logic clk);
  logic value;

  covergroup cg @(posedge clk);
    cp: coverpoint value;
  endgroup

  localparam int WIDTH = 4;
  logic [WIDTH-1:0] data;
endinterface

module top;
  logic clk;
  cov_if dut(clk);
  initial begin
    if ($bits(dut.data) != 4) $fatal(1, "localparam lost after covergroup");
    $display("PASSED");
  end
endmodule
