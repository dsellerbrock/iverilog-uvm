`timescale 1ns/1ps
module issue2479_sdf_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue2479_sdf_default_scope;
  reg a = 0;
  wire y;
  issue2479_sdf_buf u1(a, y);

  always @(y) if ($time > 0) $display("Y %0t %b", $time, y);

  initial begin : blk
    $sdf_annotate("ivltests/issue2479_sdf_default_scope.sdf");
    #5 a = 1;
    #10 $finish;
  end
endmodule
