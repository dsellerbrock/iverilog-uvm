// M9-NFA: standalone `first_match` is transparent and legacy-supported
// -- an attempt clears its slot on the first (shortest) accept, giving
// per-attempt existence semantics identical to the underlying window.
// Both engines agree (verdict parity); this pins that first_match does
// not change standalone existence/count. (Composed first_match --
// first_match(seq) ##1 c cutting the longer match -- needs the
// sequence-expression tree IR and is a separate arc.)
module first_match_t;
  logic clk = 0, a=0, b=0;
  always #5 clk = ~clk;

  f: cover property (@(posedge clk) first_match(a ##[1:3] b));
  p: cover property (@(posedge clk) a ##[1:3] b);

  initial begin
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1;      // b at offset 1
    @(negedge clk) b=0;
    @(negedge clk) b=1;           // b at offset 3 (same attempt)
    @(negedge clk) b=0;
    repeat(3) @(negedge clk);
    $display("first_match=%0d plain=%0d", _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
