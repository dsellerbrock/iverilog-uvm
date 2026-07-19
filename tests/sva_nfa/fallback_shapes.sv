// M9-NFA dual-run seed: shapes stage A intentionally leaves to the
// legacy engine (overlapped |-> consequent, cover, final-position
// unbounded delay). Both runs must lower identically through the
// legacy path — this guards the hook's fallback boundary.
// NFA-EXPECT-FALLBACK
module fallback_shapes;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  o1: assert property (@(posedge clk) a |-> b)
        else $display("o1 FAIL at %0t", $time);
  c1: cover property (@(posedge clk) a ##1 b)
        $display("c1 COVER at %0t", $time);
  u1: assert property (@(posedge clk) a ##[1:$] b)
        else $display("u1 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1; b = 1;     // o1 holds; c1 covers; u1 satisfied
    repeat (2) @(negedge clk);
    b = 0;                           // o1 FAILs while a&&!b
    @(negedge clk) a = 0;
    repeat (2) @(negedge clk);
    $finish(0);                      // u1 leaves pending obligations
  end
endmodule
