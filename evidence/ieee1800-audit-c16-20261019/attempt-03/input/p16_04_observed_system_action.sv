module test;
  bit a = 0;
  wire not_a = ~a;

  always_comb assert #0 (not_a != a) else $display("GLITCH_FAIL");

  initial begin
    #1 a = 1'b1;
    #1;
    assert #0 (1'b0) else $display("STABLE_FAIL");
    #1 $display("PASSED");
  end
endmodule
