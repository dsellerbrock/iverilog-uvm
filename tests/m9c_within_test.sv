// M9C: SVA `within` operator (IEEE 1800-2017 16.9.6). `s1 within s2`
// matches over s2's interval iff s2 matches and s1 matches at some
// embedded offset. Previously a loud sorry. Lowered to a $past-sampled
// combinational match indicator: AND of s2's cycles, AND'd with the OR
// (over embedding offsets) of s1's cycles, with a $past(1,L2) warm-up
// guard so windows predating time 0 raise no obligation.
//
// Test: s2 = (x ##1 x ##1 x) held all-ones (L2=2), s1 = b (L1=0). Then
// `b within s2` reduces to "b is true somewhere in the last 3 cycles" —
// exercising the 3-offset disjunction. Under the every-cycle assert
// semantics it fails exactly when b has a 3-cycle all-zero window.
module m9c_within_test_top;
  logic clk = 0, x = 1, b = 1;
  int fails = 0;
  int errors = 0;
  always #5 clk = ~clk;

  w: assert property (@(posedge clk) b within (x ##1 x ##1 x)) else fails++;

  // b pattern over 16 cycles; the only 3+-cycle all-zero run is idx 7..11
  // (five zeros). Windows [T-2,T] fully inside that run: T = 9, 10, 11.
  //  idx: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
  //  b:   1 0 0 1 0 0 1 0 0 0 0  0  1  0  0  1
  localparam int N = 16;
  bit [0:N-1] bv = 16'b1001_0010_0000_1001;

  initial begin
    // Two warm-up cycles (b=1, x=1): inside the $past guard window.
    x=1; b=1; @(posedge clk); #1;
    x=1; b=1; @(posedge clk); #1;
    for (int i = 0; i < N; i++) begin
      x = 1; b = bv[i];
      @(posedge clk); #1;
    end
    // Trailing cycles with b=1 (no new all-zero window).
    x=1; b=1; @(posedge clk); #1;
    x=1; b=1; @(posedge clk); #1;

    if (fails !== 3) begin
      $display("FAIL: within fails got=%0d exp=3", fails);
      errors++;
    end

    if (errors == 0) $display("PASS: m9c within");
    else $display("FAIL: m9c within (%0d errors)", errors);
    $finish(0);
  end
endmodule
