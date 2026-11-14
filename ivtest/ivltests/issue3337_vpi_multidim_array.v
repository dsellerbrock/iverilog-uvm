// Issue #3337 (IEEE 1800-2023 37.16/37.17, 38.19, 38.20): VPI sees a
// multidimensional unpacked array by dimension, not as a flat word list.
module top;
  logic [1:0] vm [1:0][5:4];
  wire  [1:0] wm [1:0][5:4];
  logic [7:0] v3 [0:1][2:0][4:5];
  logic [1:0] va [3:2];
  assign wm[1][5] = 2'd3;
  initial begin
    #0;
    vm[1][5] = 2'd2;
    vm[0][4] = 2'd1;
    v3[1][0][5] = 8'h5a;
    va[3] = 2'b10;
    $probe_multidim;
    $finish;
  end
endmodule
