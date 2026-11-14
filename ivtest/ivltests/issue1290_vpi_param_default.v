// Issues #1290 and #1292: a value parameter's vpiExpr is its default
// expression (IEEE 1800-2023 37.28 detail 3), and a defparam statement is
// a def param object of its module with vpiLhs and vpiRhs (37.28).
module child #(parameter int P = 4, parameter int Q = P + 1,
               parameter [3:0] N = 4'd9) ();
endmodule

module top;
  parameter int A = 1;
  child u1();
  child #(.P(10), .N(4'd2)) u2();
  child u3();
  defparam u3.P = A + 6;
  initial #1 $pprobe;
endmodule
