`timescale 1ns/1ns
module issue2699_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue2699_pathpulse_order;
  reg a = 0;
  wire y;
  issue2699_buf u(a, y);

  always @(y) $display("Y %0t %b", $time, y);

  initial begin
    $sdf_annotate("ivltests/issue2699_pathpulse_order.sdf", issue2699_pathpulse_order);
    #10 a = 1;
    #2 a = 0;
    #20;
    $display("PASSED");
    $finish;
  end
endmodule
