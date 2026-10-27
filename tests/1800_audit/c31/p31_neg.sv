`timescale 1ns/1ns

module ff(input clk, input d, output reg q);
  wire dclk, dd;
  reg notifier = 0;

  always @(posedge dclk) q <= dd;

  specify
    $setuphold(posedge clk, d, -2, 6, notifier, , , dclk, dd);
  endspecify
endmodule

module p31_neg;
  reg clk = 0, d = 0;
  wire q;
  integer notifier_changes = 0;

  ff u(clk, d, q);
  always @(u.notifier) notifier_changes++;

  initial begin
    #10 clk = 1;
    #1 d = 1;
    #9 $display("A q=%b nc=%0d", q, notifier_changes);
    clk = 0;
    #10 d = 0;
    #10 clk = 1;
    #4 d = 1;
    #10 $display("B nc=%0d", notifier_changes);
  end
endmodule
