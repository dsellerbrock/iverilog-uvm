`include <sv_include_angle.vh>

module sv_include_angle;
  initial begin
    if (`SV_INCLUDE_ANGLE_VALUE != 951)
      $fatal(1, "angle-bracket include value mismatch");
    $display("PASSED");
  end
endmodule
