// randsequence source-level expansion (IEEE 1800-2017 18.17) cannot unroll a
// recursive/reused production; it must reject such a grammar with a loud
// diagnostic rather than silently mis-expand.
module randsequence_recursion;
  initial begin
    randsequence (main)
      main : { $display("x"); } main ;   // self-recursive -> loud sorry
    endsequence
  end
endmodule
