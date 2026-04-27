// Test: unpacked array parameter
package test_pkg;
  parameter logic [3:0] PERMIT [4] = '{4'b0011, 4'b1100, 4'b0101, 4'b1111};
endpackage

import test_pkg::*;

module top;
  initial begin
    $display("PERMIT[0] = %b (expect 0011)", PERMIT[0]);
    $display("PERMIT[1] = %b (expect 1100)", PERMIT[1]);
    $display("PERMIT[2] = %b (expect 0101)", PERMIT[2]);
    $display("PERMIT[3] = %b (expect 1111)", PERMIT[3]);
    if (PERMIT[0] == 4'b0011 && PERMIT[1] == 4'b1100 &&
        PERMIT[2] == 4'b0101 && PERMIT[3] == 4'b1111)
      $display("PASS: all array param values correct");
    else
      $display("FAIL: wrong values");
  end
endmodule
