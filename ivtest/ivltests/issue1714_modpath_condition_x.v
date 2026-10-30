`timescale 1ns/1ns
module sel(input a, input [1:0] mode, output y);
  assign y = a;
  specify
    if (mode == 0) (a => y) = (6, 6);
    if (mode[1]) (a => y) = (1, 7);
  endspecify
endmodule

module issue1714_modpath_condition_x;
  reg s = 0;
  reg [1:0] mode = 2'bxx;
  reg [1:0] mode_z = 2'bzz;
  wire ys, yz;
  sel ux(s, mode, ys);
  sel uz(s, mode_z, yz);
  initial begin
    #10 s = 1;
    #0;
    if (ys !== 1'b0 || yz !== 1'b0) $fatal(1, "path transition was not delayed");
    #1;
    if (ys !== 1'b1 || yz !== 1'b1)
      $fatal(1, "X/Z path conditions should select 1ns rise delay, got %b/%b at %0t", ys, yz, $time);
    $display("ys %b at %0t", ys, $time);
    $finish;
  end
endmodule
