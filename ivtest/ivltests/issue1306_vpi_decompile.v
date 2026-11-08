// Issue #1306: vpiDecompile of system task/function calls and of their
// constant arguments (IEEE 1800-2023 37.42 detail 9, 37.59 detail 2).
module top;
  logic my_var;
  int a = 2;
  initial begin
    // The LRM's own example (37.42 detail 8): "" is a string constant, the
    // omitted arguments are vpiNullOp operations, null is vpiNullConst.
    $probe(1, "", , null, );
    $probe(my_var, "x\"y", 4'b10x1, 8'shf0, a);
    $exprprobe(3);
    $finish;
  end
endmodule
