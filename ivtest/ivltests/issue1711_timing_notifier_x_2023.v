`timescale 1ns/1ps
module issue1711_dut(input clk, d, output reg notifier);
  specify
    $setup(d, posedge clk, 2, notifier);
  endspecify
endmodule

module issue1711_timing_notifier_x;
  reg clk = 0, d = 0;
  wire nx, n0, n1, nz;
  issue1711_dut ux(clk, d, nx);
  issue1711_dut u0(clk, d, n0);
  issue1711_dut u1(clk, d, n1);
  issue1711_dut uz(clk, d, nz);

  initial begin
    ux.notifier = 1'bx;
    u0.notifier = 1'b0;
    u1.notifier = 1'b1;
    uz.notifier = 1'bz;
    #10 d = 1;
    #1 clk = 1;
    #1;
    $display("notifiers=%b%b%b%b", nx, n0, n1, nz);
    if ((nx !== 1'b0 && nx !== 1'b1) || n0 !== 1'b1 ||
        n1 !== 1'b0 || nz !== 1'bz)
      $fatal(1, "timing notifier table mismatch");
    $finish;
  end
endmodule
