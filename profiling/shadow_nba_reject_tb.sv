`timescale 1ns/1ps

module tb_function;
  logic clk, a, x;
  function automatic logic f(input logic arg);
    f = arg;
  endfunction
  always_ff @(posedge clk) x <= f(a);
endmodule

module tb_delay;
  logic clk, a, x;
  always_ff @(posedge clk) x <= #1 a;
endmodule

module tb_vpi;
  logic clk, a, x;
  always_ff @(posedge clk) begin
    x <= a;
    $display("side effect");
  end
endmodule

module tb_nested_wait;
  logic clk, a, x;
  always_ff @(posedge clk) begin
    @(negedge clk) x <= a;
  end
endmodule
