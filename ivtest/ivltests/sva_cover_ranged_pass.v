// IEEE 1800-2023 16.14.3: a cover property runs its pass statement once
// per successful attempt; a cover sequence runs it "with multiplicity, for
// each match that is counted toward the total for the attempt". This holds
// for a ranged ##[m:n] and an unbounded ##[m:$] final delay.
module sva_cover_ranged_pass;
  bit clk = 0; always #5 clk = ~clk;
  bit a, b, c, d;
  // Bounded: the attempt at 5 matches at 15 (##1) and 25 (##2).
  cp: cover property (@(posedge clk) a ##[1:2] b) $display("cp match %0t", $time);
  cs: cover sequence (@(posedge clk) a ##[1:2] b) $display("cs match %0t", $time);
  // Unbounded, overlapping: attempts at 5 and 15 both match at 35; the
  // sequence's attempts match again at 45.
  up: cover property (@(posedge clk) c ##[1:$] d) $display("up match %0t", $time);
  us: cover sequence (@(posedge clk) c ##[1:$] d) $display("us match %0t", $time);
  initial begin a = 1; b = 0; #10 a = 0; b = 1; #20 b = 0; end
  initial begin c = 1; #20 c = 0; #10 d = 1; #20 d = 0; #10 $finish; end
endmodule
