// M10B-md: multi-dimensional DPI open arrays (IEEE 1800-2017 35.5.6.1,
// H.12.2). A darray-of-darray argument marshals as an svOpenArrayHandle
// whose accessors walk the object tree: svDimensions/svSize see every
// dimension, svGetArrElemPtr2/3 reach the contiguous atom leaves.
// Previously the codegen sorry'd on any non-atom element type.
module m10bmd_open_array_2d_test;
  import "DPI-C" function void sum2d(input int a[][], output int total);
  import "DPI-C" function void sum3d(input byte a[][][], output int total);
  int m[][];
  byte c[][][];
  int t2, t3;
  initial begin
    m = new[3];
    for (int i = 0; i < 3; i++) begin
      m[i] = new[4];
      for (int j = 0; j < 4; j++) m[i][j] = 10*i + j;
    end
    // Build the 3-D array bottom-up with single-index stores only
    // (multi-index darray l-values are a separate recorded corner).
    c = new[2];
    for (int i = 0; i < 2; i++) begin
      byte plane[][];
      plane = new[2];
      for (int j = 0; j < 2; j++) begin
        byte row[];
        row = new[2];
        for (int k = 0; k < 2; k++) row[k] = byte'(4*i + 2*j + k);
        plane[j] = row;
      end
      c[i] = plane;
    end
    sum2d(m, t2);
    sum3d(c, t3);
    if (t2 == 138 && t3 == 28)
      $display("PASS: 2-D and 3-D open arrays (t2=%0d t3=%0d)", t2, t3);
    else
      $display("FAIL: t2=%0d (exp 138) t3=%0d (exp 28)", t2, t3);
    $finish;
  end
endmodule
