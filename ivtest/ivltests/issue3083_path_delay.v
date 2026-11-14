`timescale 1ns/1ns
module issue3083_dut(input a, output y_int, y_real, y_pair, y_pos, y_sdf);
  assign y_int = a, y_real = a, y_pair = a, y_pos = a, y_sdf = a;
  specify
    specparam annotated = 1;
    (a => y_int) = -5;
    (a => y_real) = -2.5;
    (a => y_pair) = (-3, 4);
    (a => y_pos) = 3;
    (a => y_sdf) = (annotated - 3);
  endspecify
endmodule

module issue3083_path_delay;
  reg a = 0;
  wire yi, yr, yp, ypositive, ys;
  issue3083_dut dut(a, yi, yr, yp, ypositive, ys);
  initial begin
    $sdf_annotate("ivltests/issue3083_path_delay.sdf", dut);
    #10 a = 1;
    #1;
    if (yi !== 1 || yr !== 1 || yp !== 1 || ys !== 1 || ypositive !== 0)
      $fatal(1, "rise: int=%b real=%b pair=%b sdf=%b positive=%b", yi, yr, yp, ys, ypositive);
    #4 a = 0;
    #1;
    if (yi !== 0 || yr !== 0 || yp !== 1 || ys !== 0 || ypositive !== 1)
      $fatal(1, "fall: int=%b real=%b pair=%b sdf=%b positive=%b", yi, yr, yp, ys, ypositive);
    #4;
    if (yp !== 0 || ypositive !== 0) $fatal(1, "positive delays did not expire");
    $display("PASS");
    $finish(0);
  end
endmodule
