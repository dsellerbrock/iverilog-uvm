// IEEE 1800-2017 16.5.1: concurrent assertions sample in the PREPONED
// region -- the value *before* any update in the current time slot.
module top;
  bit clk = 0, a = 0, b = 0;
  int fails = 0, passes = 0;
  always #5 clk = ~clk;
  // At the posedge at t=5, preponed a is 0 -> antecedent false -> vacuous.
  // The blocking a=1 happens in Active at t=5, AFTER the preponed sample.
  initial begin
    #5 a = 1;          // same slot as posedge clk at t=5
       b = 0;
    #10 a = 0;
    #20 $display("preponed-sample result: fails=%0d passes=%0d", fails, passes);
       if (fails == 0) $display("PASS m6b4_sample (preponed honored)");
       else            $display("FAIL m6b4_sample (sampled Active value, not Preponed)");
       $finish(0);
  end
  ap: assert property (@(posedge clk) a |-> b) passes++; else fails++;
endmodule
