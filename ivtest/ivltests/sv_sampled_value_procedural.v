// M9-SV: PROCEDURAL sampled value functions (IEEE 1800-2017 16.9.3).
//
// $past / $rose / $fell / $stable / $changed have a value only with
// respect to a clocking event. Inside a concurrent assertion the SVA
// engine supplies one. Everywhere else they were plain system-function
// calls served by compile-progress stubs that answered
//
//     $past(e)   -> e     (the CURRENT value)
//     $rose(e)   -> 0
//     $fell(e)   -> 0
//     $stable(e) -> 1
//     $changed(e)-> 0
//
// with no diagnostic. So the ordinary testbench idiom
//
//     always @(posedge clk) if ($rose(req)) ...
//
// silently never fired, and `$past(d)' silently read d itself. Four
// further defects rode along:
//
//   * the number-of-ticks argument was ignored, so $past(d,2) and
//     $past(d,3) both answered $past(d,1);
//   * the gating expression (3rd argument) was ignored, so a gated
//     $past read the ungated history;
//   * $rose/$fell/$stable/$changed returned 32 bits instead of 1;
//   * $past of a REAL rounded the fraction away (its history register
//     was integral).
//
// A sampled call written inside an edge-triggered always block is now
// bound to that block's own clock (16.14.6 clock inference), and one
// with no enclosing event control binds to the module's `default
// clocking'. The history lives in its OWN sampler process, shifted
// under NBA: it therefore ticks once per clock edge whatever the
// reader does -- a block that waits inside its body still sees "one
// clock tick ago" rather than "one execution ago" -- and the NBA
// update lands after every Active-region reader, so sharing the edge
// with them is race-free. A call with no clock at all is diagnosed
// instead of answered wrongly.

module main;

  logic clk = 0;
  int   d   = 0;
  logic b   = 0;
  logic g   = 1;
  real  r   = 0.0;

  int fails = 0;
  int tick  = 0;

  always #5 clk = ~clk;

  // Expected value tables, indexed by tick number (1-based: the first
  // posedge is at t=5). d is driven on the negedge before each tick, so
  // at tick k the current d is k-1.
  int  exp_past1 [1:7];
  int  exp_past2 [1:7];
  int  exp_past3 [1:7];
  int  exp_gated [1:7];
  logic exp_rose [1:7];
  logic exp_fell [1:7];
  logic exp_stbl [1:7];
  logic exp_chgd [1:7];
  real  exp_pastr[1:7];

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- tick %0d %s: got %0d want %0d", tick, what, got, want);
    end
  endtask

  always @(posedge clk) begin
    tick++;
    if (tick <= 7) begin
      chk("$past(d)",       $past(d),       exp_past1[tick]);
      chk("$past(d,2)",     $past(d,2),     exp_past2[tick]);
      chk("$past(d,3)",     $past(d,3),     exp_past3[tick]);
      chk("$past(d,1,g)",   $past(d,1,g),   exp_gated[tick]);
      chk("$rose(b)",       $rose(b),       exp_rose[tick]);
      chk("$fell(b)",       $fell(b),       exp_fell[tick]);
      chk("$stable(b)",     $stable(b),     exp_stbl[tick]);
      chk("$changed(b)",    $changed(b),    exp_chgd[tick]);
      // the boolean functions are 1 bit wide, not 32 (16.9.3)
      if ($bits($rose(b))   != 1) begin
        fails++; $display("FAILED -- $rose is %0d bits, want 1", $bits($rose(b)));
      end
      if ($bits($stable(b)) != 1) begin
        fails++; $display("FAILED -- $stable is %0d bits, want 1", $bits($stable(b)));
      end
      // a real operand keeps its fraction
      if ($past(r) != exp_pastr[tick]) begin
        fails++;
        $display("FAILED -- tick %0d $past(r): got %0.2f want %0.2f",
                 tick, $past(r), exp_pastr[tick]);
      end
    end
  end

  // A second clocked block gets its own independent history: binding is
  // per block, not per module.
  int other_tick = 0;
  always @(negedge clk) begin
    other_tick++;
    if (other_tick == 4 && $past(d) !== 3) begin
      fails++;
      $display("FAILED -- negedge block $past(d)=%0d at its 4th tick (want 3)",
               $past(d));
    end
  end

  // A block that WAITS inside its body skips clock ticks. The history
  // belongs to the clock, not to the block's execution, so $past must
  // still mean "one tick ago" -- which is why the sampler is its own
  // process rather than statements spliced around the body. (#12 with a
  // period of 10 skips every other posedge: the block runs at ticks
  // 1, 3, 5, 7 and reads d from ticks 0, 2, 4, 6.)
  int slow_tick = 0;
  always @(posedge clk) begin
    slow_tick++;
    if (slow_tick == 2 && $past(d) !== 1) begin
      fails++;
      $display("FAILED -- tick-skipping block: $past(d)=%0d at its 2nd run (want 1)",
               $past(d));
    end
    if (slow_tick == 3 && $past(d) !== 3) begin
      fails++;
      $display("FAILED -- tick-skipping block: $past(d)=%0d at its 3rd run (want 3)",
               $past(d));
    end
    #12;
  end

  initial begin
    // d: 0 1 2 3 4 5 6 at ticks 1..7
    exp_past1 = '{0, 0, 1, 2, 3, 4, 5};
    exp_past2 = '{0, 0, 0, 1, 2, 3, 4};
    exp_past3 = '{0, 0, 0, 0, 1, 2, 3};
    // g is low at ticks 4 and 5, so those ticks do not sample: the
    // gated history holds the tick-3 sample (d=2) from tick 4 all the
    // way through tick 6 -- one ENABLED tick back, not one tick back.
    // Tick 6 samples again (d=5), which tick 7 then reads.
    exp_gated = '{0, 0, 1, 2, 2, 2, 5};
    // b: 0 0 1 1 0 0 0  at ticks 1..7
    exp_rose  = '{0, 0, 1, 0, 0, 0, 0};
    exp_fell  = '{0, 0, 0, 0, 1, 0, 0};
    exp_stbl  = '{1, 1, 0, 1, 0, 1, 1};
    exp_chgd  = '{0, 0, 1, 0, 1, 0, 0};
    exp_pastr = '{0.0, 0.0, 1.5, 2.5, 3.5, 4.5, 5.5};

    @(negedge clk) begin d = 1; r = 1.5; end
    @(negedge clk) begin d = 2; r = 2.5; b = 1; end
    @(negedge clk) begin d = 3; r = 3.5; g = 0; end
    @(negedge clk) begin d = 4; r = 4.5; b = 0; end
    @(negedge clk) begin d = 5; r = 5.5; g = 1; end
    @(negedge clk) begin d = 6; r = 6.5; end
    @(negedge clk);
    if (tick != 7) begin
      fails++; $display("FAILED -- saw %0d ticks, want 7", tick);
    end
    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
