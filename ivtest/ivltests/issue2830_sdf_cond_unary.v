`timescale 1ns/1ns
module issue2830_sdf_cond_not(input a, input s, input e, output y);
  assign y = a;
  specify
    if (s && !e) (a => y) = 1;
  endspecify
endmodule

module issue2830_sdf_cond_bitnot(input a, input s, input e, output y);
  assign y = a;
  specify
    if (s && ~e) (a => y) = 1;
  endspecify
endmodule

module issue2830_sdf_cond_unary;
  reg a = 0;
  reg s = 1;
  reg e = 0;
  wire y_not;
  wire y_bitnot;

  issue2830_sdf_cond_not u_not(a, s, e, y_not);
  issue2830_sdf_cond_bitnot u_bitnot(a, s, e, y_bitnot);

  initial begin
    $sdf_annotate("ivltests/issue2830_sdf_cond_unary.sdf", issue2830_sdf_cond_unary);
    #6 $display("%0t y=%b%b", $time, y_not, y_bitnot);
    a = 1;
    #2 $display("%0t y=%b%b", $time, y_not, y_bitnot);
    #4 $display("%0t y=%b%b", $time, y_not, y_bitnot);
  end
endmodule
