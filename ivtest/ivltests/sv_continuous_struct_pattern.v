module sv_continuous_struct_pattern;
  typedef struct { logic a; logic [3:0] b; } s_t;
  s_t dst;

  assign dst = '{1'b1, 4'h3};

  initial begin
    #1;
    if (dst.a !== 1'b1 || dst.b !== 4'h3)
      $fatal(1, "continuous struct pattern mismatch");
    $display("PASSED");
  end
endmodule
