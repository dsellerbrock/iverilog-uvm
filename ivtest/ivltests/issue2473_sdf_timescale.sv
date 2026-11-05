`timescale 1ns/1ps
module issue2473_sdf_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue2473_sdf_timescale;
  reg a = 0;
  wire y;
  issue2473_sdf_buf u1(a, y);

  always @(y) if ($time > 0) $display("Y %0t %b", $time, y);

  initial begin
    $sdf_annotate("ivltests/issue2473_sdf_timescale.sdf", issue2473_sdf_timescale);
    #10 a = 1;
    #60 $finish;
  end
endmodule
