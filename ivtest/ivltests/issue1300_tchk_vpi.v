// IEEE 1800-2017 37.38 / 1800-2023 37.40: timing checks are VPI objects.
`timescale 1ns/1ns
module tcell(input data, input clk, input en, input [3:0] bus);
  reg notifier = 0;
  specify
    $setup(posedge data, posedge clk, 1, notifier);
    $setuphold(posedge clk &&& en, bus[2], 2, 3, notifier);
    $width(negedge clk, 4);
  endspecify
endmodule

module top;
  reg data = 0, clk = 0, en = 1;
  reg [3:0] bus = 0;
  tcell u1(data, clk, en, bus);
  // data rises 3 before clk: no $setup violation at limit 1, one at the
  // limit 5 that the VPI module writes at the start of simulation.
  initial begin
    #7 data = 1;
    #3 clk = 1;
    #1 $display("notifier=%b", u1.notifier);
    if (u1.notifier === 1'b1) $display("PASSED");
    $finish;
  end
endmodule
