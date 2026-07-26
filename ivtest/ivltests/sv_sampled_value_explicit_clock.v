// M9-SV / R14: an EXPLICIT clocking event as the last argument of a
// sampled value function -- `$past(e, n, gate, @(posedge sclk))'
// (IEEE 1800-2017 16.9.3).
//
// This did not parse at all: the argument list takes expressions and an
// event control is not one, so the form was a bare syntax error. It now
// has its own grammar rule at zero conflict cost (494 shift/reduce,
// 1161 reduce/reduce, unchanged) -- the token after the comma decides,
// and `@' can never start an argument.
//
// The named event outranks both other clock sources of 16.14.6: the
// enclosing procedural event control and the module's default clocking.
// Both are present below and both are the WRONG answer, so a binding
// that fell back to either shows up as a value mismatch rather than as
// nothing happening.
//
// Stimulus is arranged so the sampling clock never has an edge at the
// same time as a write to the sampled variable -- otherwise the sampler
// and the driver would race in the Active region and the expected value
// would depend on process order, which the LRM does not define.
//
//   clk  posedges: 5, 15, 25, 35, 45, 55   <- reader, and default clocking
//   sclk posedges: 10, 30, 50              <- the NAMED clock
//   d is written at clk posedges, so it never changes at an sclk edge.

module main;

  logic clk  = 0;
  logic sclk = 0;
  int   d    = 0;
  logic g    = 1;

  int fails = 0;
  int n     = 0;

  always #5  clk  = ~clk;
  always #10 sclk = ~sclk;

  default clocking cb @(posedge clk); endclocking

  // d: 1,2,3,4,5,6 at clk posedges 5,15,25,35,45,55.
  // The sclk sampler therefore records d=1 (t=10), d=3 (t=30), d=5 (t=50).
  always @(posedge clk) d <= d + 1;

  // The reader's own clock is clk and the default clocking is clk, but
  // the call names sclk: its history may only advance at 10, 30 and 50.
  int seen [1:6];
  always @(posedge clk) begin
    n++;
    if (n <= 6) seen[n] = $past(d, 1, g, @(posedge sclk));
  end

  initial begin
    #58;

    // Ticks 1 and 2 (t=5, 15) precede or immediately follow the first
    // sclk tick, so the history is still at its initial 0.
    if (seen[1] !== 0) begin
      fails++; $display("FAILED -- tick 1: got %0d want 0", seen[1]);
    end
    if (seen[2] !== 1) begin
      fails++; $display("FAILED -- tick 2: got %0d want 1 (the t=10 sample)", seen[2]);
    end
    // No sclk tick between t=15 and t=25, so tick 3 must read the same
    // value as tick 2. This is the check that actually distinguishes the
    // named clock from the enclosing one: bound to clk the value would
    // change at every tick.
    if (seen[3] !== seen[2]) begin
      fails++;
      $display("FAILED -- tick 3 changed to %0d with no sclk edge between (want %0d): the call took the wrong clock",
               seen[3], seen[2]);
    end
    // t=30 is an sclk tick and d is 3 there, so tick 4 (t=35) sees it.
    if (seen[4] !== 3) begin
      fails++; $display("FAILED -- tick 4: got %0d want 3 (the t=30 sample)", seen[4]);
    end
    if (seen[5] !== seen[4]) begin
      fails++;
      $display("FAILED -- tick 5 changed to %0d with no sclk edge between (want %0d)",
               seen[5], seen[4]);
    end
    // t=50 is an sclk tick with d=5.
    if (seen[6] !== 5) begin
      fails++; $display("FAILED -- tick 6: got %0d want 5 (the t=50 sample)", seen[6]);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
