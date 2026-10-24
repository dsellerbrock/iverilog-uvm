`timescale 1ns/1ps
module sub;
  reg [7:0] data = 8'h3c;
  reg [7:0] out = 0;
endmodule

module test;
  reg clk = 0;
  always #5 clk = ~clk;

  sub dut();

  clocking cb @(posedge clk);
    input s_data = dut.data;
    output s_out = dut.out;
  endclocking

  initial begin
    @(cb);
    if (cb.s_data !== 8'h3c) begin
      $display("FAIL: cb.s_data expected 8'h3c, got %h", cb.s_data);
      $finish(1);
    end
    cb.s_out <= 8'ha5;
    @(cb);
    #1;
    if (dut.out !== 8'ha5) begin
      $display("FAIL: dut.out expected 8'ha5, got %h", dut.out);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
