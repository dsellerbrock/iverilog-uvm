`timescale 1ns/1ps
module issue2481_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue2481_sdf_instance_wildcard;
  reg a = 0;
  wire y1, y2;
  issue2481_buf u1(a, y1);
  issue2481_buf u2(a, y2);

  always @(y1) if ($time > 0) $display("Y1 %0t %b", $time, y1);
  always @(y2) if ($time > 0) $display("Y2 %0t %b", $time, y2);

  initial begin
    $sdf_annotate("ivltests/issue2481_sdf_instance_wildcard.sdf",
                  issue2481_sdf_instance_wildcard);
    #5 a = 1;
    #10 $finish;
  end
endmodule
