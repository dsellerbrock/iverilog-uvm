module t;
  logic settle = 1'b0;

  // A module assertion item denotes its own implicit always_comb process.
  // The first false evaluation is flushed when that process resumes after
  // settle changes in the same slot, so STALE must never print.
  settle_a: assert #0 (settle) else $display("STALE");

  // A constant item still executes once at time zero.
  static_a: assert #0 (1'b0) else $display("STATIC_FAIL %m");

  generate
    for (genvar i = 0; i < 3; i++) begin : g
      gen_a: assert #0 (i != 1) else $display("GEN_FAIL %m");
    end
  endgenerate

  initial begin
    #0 settle = 1'b1;
    #1 $display("PASSED");
  end
endmodule
