`timescale 1ns/1ns
module issue2828_leaf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule
module issue2828_mid(input a, output y);
  issue2828_leaf l(a, y);
endmodule
module issue2828_sdf_whitespace;
  reg a = 0;
  wire y;
  issue2828_mid m(a, y);
  always @(y) $display("%0t y=%b", $time, y);
  initial begin
    $sdf_annotate("ivltests/issue2828_sdf_whitespace.sdf", issue2828_sdf_whitespace);
    #10 a = 1;
    #20 $finish;
  end
endmodule
