module sv_continuous_struct_variable;
  typedef struct { logic a; logic [3:0] b; } s_t;
  s_t src, dst;

  assign dst = src;

  initial begin
    src.a = 1'b1;
    src.b = 4'h3;
    #1;
    if (dst.a !== 1'b1 || dst.b !== 4'h3)
      $fatal(1, "continuous struct assignment mismatch");
    src.a = 1'b0;
    src.b = 4'hc;
    #1;
    if (dst.a !== 1'b0 || dst.b !== 4'hc)
      $fatal(1, "continuous struct assignment did not follow source changes");
    $display("PASSED");
  end
endmodule
