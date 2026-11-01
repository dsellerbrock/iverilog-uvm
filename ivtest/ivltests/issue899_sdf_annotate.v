`timescale 1ns/1ps
module issue899_sdf_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue899_sdf_annotate;
  reg a = 0;
  wire y;
  issue899_sdf_buf u(a, y);

  always @(y) $display("Y %0.3f %b", $realtime, y);

  initial begin
    $sdf_annotate("ivltests/issue899_sdf_annotate.sdf", , , , "MINIMUM",
                  "1.0:1.0:1.0", "FROM_MTM");
    #10 a = 1;
    #10 a = 0;
    $sdf_annotate("ivltests/issue899_sdf_annotate.sdf", issue899_sdf_annotate,
                  , , "TYPICAL", "1.0:1.0:1.0", "FROM_MTM");
    #10 a = 1;
    #10 a = 0;
    $sdf_annotate("ivltests/issue899_sdf_annotate.sdf", issue899_sdf_annotate,
                  , , "MAXIMUM", "1.0:1.0:1.0", "FROM_MTM");
    #10 a = 1;
    #10 a = 0;
    $sdf_annotate("ivltests/issue899_sdf_annotate.sdf", issue899_sdf_annotate,
                  , , "MAXIMUM", "2.0:3.0:4.0", "FROM_TYPICAL");
    #10 a = 1;
    #25 a = 0;
    #21;
    $sdf_annotate("ivltests/issue899_sdf_annotate.sdf", issue899_sdf_annotate,
                  , , "MAXIMUM", "2.0:3.0:4.0", "FROM_MINIMUM");
    #10 a = 1;
    #25 a = 0;
    #21;
    $sdf_annotate("ivltests/issue899_sdf_annotate.sdf", issue899_sdf_annotate,
                  , , "MINIMUM", "2.0:3.0:4.0", "FROM_MAXIMUM");
    #10 a = 1;
    #25 a = 0;
  end
endmodule
