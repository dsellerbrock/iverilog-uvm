// Issue #2989: IEEE 1800-2017/2023 16.8.1. A cycle delay that names a
// sequence or property formal is constant once a constant actual is
// substituted, including a typed (shortint) formal, whose actual is cast
// to the formal type first.
module issue2989_seq_formal_delay;
  bit clk = 0;
  bit a, b;
  int h_typed, h_untyped, h_prop, h_arith, fails;
  always #5 clk = ~clk;
  sequence s_typed(shortint delay); 1'b1 ##delay 1'b1; endsequence
  sequence s_untyped(delay); 1'b1 ##delay 1'b1; endsequence
  sequence s_arith(int d); a ##(d+1) b; endsequence
  property p_untyped(delay); 1'b1 ##delay 1'b1; endproperty
  property p_impl(d); a |-> ##d b; endproperty
  cover property (@(posedge clk) s_typed(1)) h_typed++;
  cover property (@(posedge clk) s_untyped(1)) h_untyped++;
  cover property (@(posedge clk) p_untyped(1)) h_prop++;
  cover property (@(posedge clk) s_arith(1)) h_arith++;
  assert property (@(posedge clk) p_impl(2)) else fails++;
  initial begin
    a = 1;
    @(posedge clk); #1 a = 0;
    @(posedge clk); #1 b = 1;
    @(posedge clk); #1 b = 0;
    #1;
    // The single-cycle covers start at 5, 15 and match at 15 and 25.
    if (h_typed != 2 || h_untyped != 2 || h_prop != 2 || h_arith != 1
        || fails != 0)
      $display("FAILED typed=%0d untyped=%0d prop=%0d arith=%0d fails=%0d",
               h_typed, h_untyped, h_prop, h_arith, fails);
    else
      $display("PASSED");
    $finish;
  end
endmodule
