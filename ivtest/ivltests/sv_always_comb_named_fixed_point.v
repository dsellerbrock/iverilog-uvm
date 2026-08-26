// The fixed-point transaction belongs to the enclosing always_comb process,
// including a static named sequential block lowered through a joined child
// vthread.  The named bodies must therefore quiesce just like inline bodies.
module sv_always_comb_named_fixed_point;
  logic a = 1'b0;
  logic b = 1'b0;

  always_comb begin : compute_a
    a = ~b;
    a = b;
  end

  always_comb begin : compute_b
    b = ~a;
    b = a;
  end

  initial begin
    #1;
    if (a !== 1'b0 || b !== 1'b0)
      $display("FAILED: a=%b b=%b", a, b);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
