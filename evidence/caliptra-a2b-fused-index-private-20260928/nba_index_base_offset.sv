`timescale 1ns/1ps
module tb;
  logic clk = 0;
  always #5 clk = ~clk;
  logic [1:0][3:0][1:0] value;
  logic signed [31:0] j;
  for (genvar i = 0; i < 2; i++) begin : g
    always @(posedge clk) value[i][j] <= i ? 2'b10 : 2'b01;
  end
  task automatic exercise(input logic signed [31:0] index_value);
    @(negedge clk);
    value = '0;
    j = index_value;
    @(posedge clk); #1;
    $display("index=%h value=%b", j, value);
  endtask
  initial begin
    $watch_nba(value);
    exercise(0);
    exercise(1);
    exercise(3);
    exercise(4);
    exercise(-1);
    exercise(32'h7fffffff);
    exercise(32'h80000000);
    exercise(32'hxxxxxxxx);
    exercise(32'hzzzzzzzz);
    force j = 32'd2;
    exercise(3);
    release j;
    exercise(1);
    $finish;
  end
endmodule
