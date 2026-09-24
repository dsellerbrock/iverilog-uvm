`timescale 1ns/1ps
module sv_packed_partial_feedback;
  reg clk = 0;
  logic [1:0] payload;
  logic [1:0][1:0] independent, dependent;
  logic [2:0][1:0][1:0] nested;
  logic [3:0] unrelated_reader;
  logic unrelated_compare;
  logic [2:0] whole_read, registered;
  bit [3:0] two_state;
  reg delayed;

  always #0.5 clk = ~clk;
  assign independent[0] = payload;
  assign independent[1][0] = 1'b1;
  assign unrelated_reader = independent;
  assign unrelated_compare = independent[0] < 2'b10;
  assign dependent[0] = payload;
  assign dependent[1][0] = dependent[0][0];
  assign nested[0] = {2'b10, payload};
  assign nested[1][0] = nested[0][0];
  assign nested[2][0] = nested[1][0];
  assign whole_read[0] = 1'b1;
  assign whole_read[1] = |whole_read;
  assign two_state[0] = payload[0];
  assign registered[0] = payload[0];
  assign registered[1] = delayed;
  always @(posedge clk) delayed <= registered[0];

  initial begin
    payload = 2'b01;
    #1;
    if (independent[0] !== 2'b01 || independent[1][0] !== 1'b1 ||
        unrelated_reader !== 4'bz101 || unrelated_compare !== 1'b1 ||
        dependent[0] !== 2'b01 || dependent[1][0] !== 1'b1 ||
        nested[0][0] !== 2'b01 || nested[1][0] !== 2'b01 ||
        nested[2][0] !== 2'b01 || whole_read !== 3'bz11 ||
        two_state !== 4'b0001 || registered !== 3'bz11)
      $fatal(1, "packed partial feedback lost initial value");
    payload = 2'b10;
    #1;
    if (independent[0] !== 2'b10 || independent[1][0] !== 1'b1 ||
        unrelated_reader !== 4'bz110 || unrelated_compare !== 1'b0 ||
        dependent[0] !== 2'b10 || dependent[1][0] !== 1'b0 ||
        nested[0][0] !== 2'b10 || nested[1][0] !== 2'b10 ||
        nested[2][0] !== 2'b10 || whole_read !== 3'bz11 ||
        two_state !== 4'b0000 || registered !== 3'bz00)
      $fatal(1, "packed partial feedback lost changed value");
    $display("PASSED");
    $finish(0);
  end
endmodule
