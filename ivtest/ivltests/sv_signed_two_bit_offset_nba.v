`timescale 1ns/1ps
module tb;
  logic clk = 0;
  logic run_clock = 1;
  initial while (run_clock) begin #5 clk = ~clk; end
  logic [1:0][3:0][1:0] value;
  logic signed [31:0] j;

  for (genvar i = 0; i < 2; i++) begin : lane
    always @(posedge clk) value[i][j] <= i ? 2'b10 : 2'b01;
  end

  task automatic exercise(input logic signed [31:0] index_value,
                          input logic [15:0] expected);
    @(negedge clk);
    value = '0;
    j = index_value;
    @(posedge clk); #1;
    if (value !== expected)
      $fatal(1, "j=%h: got %h expected %h", j, value, expected);
  endtask

  initial begin
    exercise(0, 16'h0201);
    exercise(1, 16'h0804);
    exercise(3, 16'h8040);
    exercise(4, 16'h0100);
    exercise(-1, 16'h0080);
    exercise(32'h7fffffff, 16'h0000);
    exercise(32'h80000000, 16'h0000);
    exercise(32'hxxxxxxxx, 16'h0000);
    exercise(32'hzzzzzzzz, 16'h0000);
    force j = 32'd2;
    exercise(3, 16'h2010);
    if (j !== 2) $fatal(1, "forced index was not observed");
    release j;
    exercise(1, 16'h0804);
    $display("PASSED");
    run_clock = 0;
  end
endmodule
