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
// R15 audit: 16.9.3 defines $past in terms of clocking-event time steps
// STRICTLY PRIOR to the time step in which the call is evaluated. Thus a
// call evaluated on an sclk tick excludes that tick, while a call between
// sclk ticks includes the most recent tick. The NBA history shift already
// implements both cases: aligned Active-region readers see the pre-shift
// chain, and later unaligned readers see the completed shift. Depths one
// and two below pin both sides so adding an extra unaligned delay cannot
// masquerade as a fix.
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
  logic b    = 0;
  logic g    = 1;

  int fails = 0;
  int n     = 0;
  int sn    = 0;

  always #5  clk  = ~clk;
  always #10 sclk = ~sclk;

  // b is 0/1/0 at the three sclk ticks. It changes between ticks so
  // unaligned value-change calls also prove which two time steps are
  // compared.
  initial begin
    #20 b = 1;
    #20 b = 0;
  end

  default clocking cb @(posedge clk); endclocking

  // d: 1,2,3,4,5,6 at clk posedges 5,15,25,35,45,55.
  // The sclk sampler therefore records d=1 (t=10), d=3 (t=30), d=5 (t=50).
  always @(posedge clk) d <= d + 1;

  // The reader's own clock is clk and the default clocking is clk, but
  // the call names sclk: its history may only advance at 10, 30 and 50.
  int seen1 [1:6];
  int seen2 [1:6];
  logic seen_rose    [1:6];
  logic seen_fell    [1:6];
  logic seen_stable  [1:6];
  logic seen_changed [1:6];
  always @(posedge clk) begin
    n++;
    if (n <= 6) begin
      seen1[n] = $past(d, 1, g, @(posedge sclk));
      seen2[n] = $past(d, 2, g, @(posedge sclk));
      seen_rose[n]    = $rose(b, @(posedge sclk));
      seen_fell[n]    = $fell(b, @(posedge sclk));
      seen_stable[n]  = $stable(b, @(posedge sclk));
      seen_changed[n] = $changed(b, @(posedge sclk));
    end
  end

  // These reads occur in the sclk event's own time step. The current
  // tick is not "strictly prior", so depth one starts at the preceding
  // sclk tick and depth two at the tick before that.
  int aligned1 [1:3];
  int aligned2 [1:3];
  logic aligned_rose    [1:3];
  logic aligned_fell    [1:3];
  logic aligned_stable  [1:3];
  logic aligned_changed [1:3];
  always @(posedge sclk) begin
    sn++;
    if (sn <= 3) begin
      aligned1[sn] = $past(d, 1, g, @(posedge sclk));
      aligned2[sn] = $past(d, 2, g, @(posedge sclk));
      aligned_rose[sn]    = $rose(b, @(posedge sclk));
      aligned_fell[sn]    = $fell(b, @(posedge sclk));
      aligned_stable[sn]  = $stable(b, @(posedge sclk));
      aligned_changed[sn] = $changed(b, @(posedge sclk));
    end
  end

  initial begin
    #58;

    // Unaligned reads: the most recent sclk tick is strictly prior and
    // is therefore the depth-one result.
    if (seen1[1] !== 0) begin
      fails++; $display("FAILED -- tick 1 depth 1: got %0d want 0", seen1[1]);
    end
    if (seen1[2] !== 1) begin
      fails++; $display("FAILED -- tick 2 depth 1: got %0d want 1 (the t=10 sample)", seen1[2]);
    end
    // No sclk tick between t=15 and t=25, so tick 3 must read the same
    // value as tick 2. This is the check that actually distinguishes the
    // named clock from the enclosing one: bound to clk the value would
    // change at every tick.
    if (seen1[3] !== seen1[2]) begin
      fails++;
      $display("FAILED -- tick 3 changed to %0d with no sclk edge between (want %0d): the call took the wrong clock",
               seen1[3], seen1[2]);
    end
    // t=30 is an sclk tick and d is 3 there, so tick 4 (t=35) sees it.
    if (seen1[4] !== 3) begin
      fails++; $display("FAILED -- tick 4 depth 1: got %0d want 3 (the t=30 sample)", seen1[4]);
    end
    if (seen1[5] !== seen1[4]) begin
      fails++;
      $display("FAILED -- tick 5 changed to %0d with no sclk edge between (want %0d)",
               seen1[5], seen1[4]);
    end
    // t=50 is an sclk tick with d=5.
    if (seen1[6] !== 5) begin
      fails++; $display("FAILED -- tick 6 depth 1: got %0d want 5 (the t=50 sample)", seen1[6]);
    end

    if (seen2[1] !== 0 || seen2[2] !== 0 || seen2[3] !== 0 ||
        seen2[4] !== 1 || seen2[5] !== 1 || seen2[6] !== 3) begin
      fails++;
      $display("FAILED -- unaligned depth 2: got %0d %0d %0d %0d %0d %0d want 0 0 0 1 1 3",
               seen2[1], seen2[2], seen2[3],
               seen2[4], seen2[5], seen2[6]);
    end

    // A value-change function compares the expression's sampled value
    // in the call's current time step with its sample at the most recent
    // strictly-prior named-clock time step. b changes at t=20 and t=40,
    // so the unaligned calls see those transitions immediately; after
    // the following sclk tick the two sampled values agree again.
    if (seen_rose[1] !== 0 || seen_rose[2] !== 0 ||
        seen_rose[3] !== 1 || seen_rose[4] !== 0 ||
        seen_rose[5] !== 0 || seen_rose[6] !== 0) begin
      fails++;
      $display("FAILED -- unaligned rose sequence");
    end
    if (seen_fell[1] !== 0 || seen_fell[2] !== 0 ||
        seen_fell[3] !== 0 || seen_fell[4] !== 0 ||
        seen_fell[5] !== 1 || seen_fell[6] !== 0) begin
      fails++;
      $display("FAILED -- unaligned fell sequence");
    end
    if (seen_stable[1] !== 1 || seen_stable[2] !== 1 ||
        seen_stable[3] !== 0 || seen_stable[4] !== 1 ||
        seen_stable[5] !== 0 || seen_stable[6] !== 1) begin
      fails++;
      $display("FAILED -- unaligned stable sequence");
    end
    if (seen_changed[1] !== 0 || seen_changed[2] !== 0 ||
        seen_changed[3] !== 1 || seen_changed[4] !== 0 ||
        seen_changed[5] !== 1 || seen_changed[6] !== 0) begin
      fails++;
      $display("FAILED -- unaligned changed sequence");
    end

    // Aligned reads exclude the event in their own time step.
    if (aligned1[1] !== 0 || aligned1[2] !== 1 || aligned1[3] !== 3) begin
      fails++;
      $display("FAILED -- aligned depth 1: got %0d %0d %0d want 0 1 3",
               aligned1[1], aligned1[2], aligned1[3]);
    end
    if (aligned2[1] !== 0 || aligned2[2] !== 0 || aligned2[3] !== 1) begin
      fails++;
      $display("FAILED -- aligned depth 2: got %0d %0d %0d want 0 0 1",
               aligned2[1], aligned2[2], aligned2[3]);
    end
    if (aligned_rose[2] !== 1 || aligned_fell[2] !== 0 ||
        aligned_stable[2] !== 0 || aligned_changed[2] !== 1) begin
      fails++;
      $display("FAILED -- aligned rising transition");
    end
    if (aligned_rose[3] !== 0 || aligned_fell[3] !== 1 ||
        aligned_stable[3] !== 0 || aligned_changed[3] !== 1) begin
      fails++;
      $display("FAILED -- aligned falling transition");
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
