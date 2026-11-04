`timescale 1ns/1ps
module issue2480_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue2480_sdf_line;
  reg a = 0;
  wire y;
  issue2480_buf u1(a, y);

  initial begin
    $sdf_annotate("ivltests/issue2480_sdf_line_a.sdf", issue2480_sdf_line);
    $sdf_annotate("ivltests/issue2480_sdf_line_b.sdf", issue2480_sdf_line);
  end
endmodule
