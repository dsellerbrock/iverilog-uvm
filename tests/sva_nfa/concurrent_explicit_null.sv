// IEEE 1800-2017 16.14.2: an explicit null else action (`else ;') is
// intentionally silent. It is distinct from an omitted else arm, which uses
// the default $error action. Exercise both concurrent-action grammar forms
// and repeat them behind 16.14.6 procedural clock inference.
// NFA-EXPECT-FALLBACK
module concurrent_explicit_null;
  logic explicit_clk = 0;
  logic inferred_clk = 0;

  // Explicit-clock, else-only form: silent on failure.
  assert property (@(posedge explicit_clk) 1'b0) else ;

  // Explicit-clock, pass/else form: neither a pass call nor a default error.
  assert property (@(posedge explicit_clk) 1'b0)
    $display("UNEXPECTED explicit pass"); else ;

  // Omitted else retains the standard default failure action.
  assert property (@(posedge explicit_clk) 1'b0);

  always @(posedge inferred_clk) begin
    // These three assertions have no property clock. They are parked until
    // the enclosing event supplies the inferred clock.
    assert property (1'b0) else ;
    assert property (1'b0)
      $display("UNEXPECTED inferred pass"); else ;
    assert property (1'b0);
  end

  initial begin
    #5 explicit_clk = 1;
    #5 inferred_clk = 1;
    #1 $display("explicit-null control done");
    $finish(0);
  end
endmodule
