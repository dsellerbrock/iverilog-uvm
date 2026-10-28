`timescale 1ns/1ns
module issue880_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue880_multi(input a, b, output y);
  assign y = a | b;
  specify
    (a => y) = 1;
    (b => y) = 1;
  endspecify
endmodule

module issue880_vec(input [1:0] a, output [1:0] y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue880_pathpulse;
  reg a = 0, p = 0, r = 0;
  reg ma = 0, mb = 0, ca = 0, cb = 0, va = 0, sa = 0;
  wire y, py, ry, my, cy, sy;
  wire [1:0] vy;
  issue880_buf u1(a, y);
  issue880_buf u2(p, py);
  issue880_buf u3(r, ry);
  issue880_multi u4(ma, mb, my);
  issue880_multi u5(ca, cb, cy);
  issue880_vec u6({va, va}, vy);
  issue880_buf u7(sa, sy);

  always @(y)  $display("Y %0t %b", $time, y);
  always @(py) $display("P %0t %b", $time, py);
  always @(ry) $display("R %0t %b", $time, ry);
  always @(my) $display("M %0t %b", $time, my);
  always @(cy) $display("C %0t %b", $time, cy);
  always @(sy) $display("A %0t %b", $time, sy);

  initial begin
    $sdf_annotate("ivltests/issue880_pathpulse.sdf", issue880_pathpulse);
    #10 a = 1; #1 a = 0;
    #20 a = 1; #2 a = 0;
    #20 a = 1; #5 a = 0;
    #540 $finish;
  end

  initial begin
    #100 p = 1; #1 p = 0;
    #20 p = 1; #2 p = 0;
    #20 p = 1; #3 p = 0;
  end

  initial begin
    #200 r = 1; #2 r = 0;
  end

  initial begin
    #300 ma = 1; #2 ma = 0;
    #20 mb = 1; #2 mb = 0;
  end

  initial begin
    #400 ca = 1; cb = 1;
    #4 ca = 0; cb = 0;
  end

  initial begin
    #500 sa = 1; #3 sa = 0;
  end
endmodule
