// G56: array slices in continuous assigns
module g56_array_slice_assign_test;
  logic [7:0] src [0:3];
  logic [7:0] dst [0:1];

  // Continuous assign of array slice
  assign dst = src[0:1];

  initial begin
    src[0] = 8'hAA;
    src[1] = 8'hBB;
    src[2] = 8'hCC;
    src[3] = 8'hDD;
    #1;
    if (dst[0] === 8'hAA && dst[1] === 8'hBB) begin
      $display("PASS: dst[0]=%0h dst[1]=%0h", dst[0], dst[1]);
    end else begin
      $display("FAIL: dst[0]=%0h dst[1]=%0h (expected AA BB)", dst[0], dst[1]);
      $finish(1);
    end
  end
endmodule
