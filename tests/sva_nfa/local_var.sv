// M9-NFA LV-1: sequence local variable, fixed-delay capture-and-compare
// (IEEE 1800-2017 16.10). `(a, v = d) ##2 (b && (c == v))` captures the
// 8-bit d when a matches and, two cycles later, requires c to equal the
// CAPTURED value -- a per-attempt data check. Lowered by a source
// transform to $past (exact, engine-independent), so this is a
// verdict-parity test. The count distinguishes value match vs mismatch.
module local_var;
  logic clk=0, a=0, b=0;
  logic [7:0] d=0, c=0;
  always #5 clk=~clk;

  cv: cover property (@(posedge clk) (a, v = d) ##2 (b && (c == v)));

  initial begin
    // A1: capture d=A5; two cycles later c=A5 -> value matches -> counts.
    @(negedge clk) a=1; d=8'hA5;
    @(negedge clk) a=0; d=8'h11;      // d changes; must not matter
    @(negedge clk) b=1; c=8'hA5;
    @(negedge clk) b=0; c=0;
    // A2: capture d=33; two cycles later c=99 -> mismatch -> does NOT count.
    @(negedge clk) a=1; d=8'h33;
    @(negedge clk) a=0; d=8'hFF;
    @(negedge clk) b=1; c=8'h99;
    @(negedge clk) b=0; c=0;
    // A3: capture d=7E; two cycles later c=7E -> matches -> counts.
    @(negedge clk) a=1; d=8'h7E;
    @(negedge clk) a=0;
    @(negedge clk) b=1; c=8'h7E;
    @(negedge clk) b=0; c=0;
    @(negedge clk);
    $display("local_var cover=%0d (expect 2: A1 and A3 match; A2 mismatches)",
             _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
