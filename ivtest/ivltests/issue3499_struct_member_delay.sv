`timescale 1ns/100ps
module issue3499_struct_member_delay;
  logic a = 0;
  struct { int lo; int hi; } s = '{1, 3};
  wire q;
  assign #(s.hi) q = a;

  logic b = 0;
  typedef struct { int ticks; } inner_t;
  typedef struct { inner_t inner; } timing_t;
  timing_t timing = '{'{2}};
  timing_t replacement = '{'{5}};
  wire nested_q;
  assign #(timing.inner.ticks) nested_q = b;

  struct { real ns; } real_delay = '{2.75};
  real real_in = 1.25;
  wire real real_q;
  assign #(real_delay.ns) real_q = real_in;

  struct { logic [79:0] ticks; } unknown_delay = '{80'hx0000000000000000005};
  wire unknown_q;
  assign #(unknown_delay.ticks) unknown_q = a;

  struct { logic signed [3:0] ticks; } negative_delay = '{-4'sd1};
  wire negative_q;
  assign #(negative_delay.ticks) negative_q = 1'b1;

  logic mixed_in = 0;
  struct { int rise; int off; } mixed_delay = '{4, 6};
  int fall_signal = 2;
  logic signed [3:0] negative_signal = -1;
  wire fall_strength;
  assign (weak1, weak0) fall_strength = 1'b0;
  assign (strong1, strong0) fall_strength = 1'b1;
  wire two_q, three_q, strength_q, negative_mixed_q;
  wire [1:0] vector_q;
  assign #(mixed_delay.rise, 3) two_q = mixed_in;
  assign (weak1, weak0) #(mixed_delay.rise, fall_signal, mixed_delay.off)
      three_q = mixed_in;
  assign #(mixed_delay.rise, fall_strength) strength_q = mixed_in;
  assign #(mixed_delay.rise, negative_signal) negative_mixed_q = 1'b0;
  assign #(mixed_delay.rise, 3, 6) vector_q = {2{mixed_in}};

  // Make global precision finer than the local real-delay rounding unit.
  issue3499_fine_precision fine();

  int nested_changes = 0;
  always @(nested_q)
    if (nested_q !== 1'bx) nested_changes++;

  int real_changes = 0;
  always @(real_q)
    if (real_q != 0.0) begin
      real_changes++;
      if ($realtime < 2.79 || $realtime > 2.81 || real_q != 1.25)
        $fatal(1, "Real member did not round to 2.8 ns: %0g", $realtime);
    end

  initial begin
    #0.1;
    if (unknown_q !== 0) $fatal(1, "Unknown delay did not evaluate to zero");
    #1.8;
    if (nested_q !== 1'bx || three_q !== 1'bx)
      $fatal(1, "Initial fall arrived before 2 ns");
    #0.2;
    if (nested_q !== 0 || three_q !== 0)
      $fatal(1, "Initial fall did not arrive after 2 ns");
    #0.8;
    if (q !== 1'bx || two_q !== 1'bx || vector_q !== 2'bxx
        || real_changes != 1)
      $fatal(1, "Incorrect initial scalar, vector, or real delay");
    #0.2;
    if (q !== 0 || two_q !== 0 || vector_q !== 0)
      $fatal(1, "Initial fall did not arrive after 3 ns");
    #6.9;
    a = 1;
    timing.inner.ticks = 5;
    b = 1;
    mixed_in = 1;
    #1;
    if (unknown_q !== 1) $fatal(1, "Unknown delay incorrectly delayed a rise");
    timing.inner.ticks = 1;
    #1;
    if (q !== 0) $fatal(1, "Rise arrived before 13 ns");
    $display("12: q=%b", q);
    #1;
    if (nested_q !== 0) $fatal(1, "Rise used a stale or later delay");
    #0.9;
    if (two_q !== 0 || three_q !== 0 || vector_q !== 0)
      $fatal(1, "Mixed delay rise arrived before 14 ns");
    #0.1;
    if (q !== 1) $fatal(1, "Rise did not arrive at 13 ns");
    $display("14: q=%b", q);
    #0.1;
    if (two_q !== 1 || three_q !== 1 || strength_q !== 1 || vector_q !== 2'b11)
      $fatal(1, "Mixed delay rise did not arrive after 14 ns");
    #0.8;
    if (nested_q !== 0) $fatal(1, "Nested rise arrived before 15 ns");
    #0.2;
    if (nested_q !== 1 || nested_changes != 2)
      $fatal(1, "Nested rise did not arrive after 15 ns");
    #4.9;
    timing = replacement;
    b = 0;
    mixed_in = 0;
    #1 b = 1;
    #0.9;
    if (two_q !== 1 || three_q !== 1 || strength_q !== 0 || vector_q !== 2'b11)
      $fatal(1, "Mixed delay fall arrived before 22 ns");
    #0.2;
    if (two_q !== 1 || three_q !== 0 || vector_q !== 2'b11)
      $fatal(1, "Fall did not use the ordinary variable delay");
    #1;
    if (two_q !== 0 || vector_q !== 0)
      $fatal(1, "Fall did not use the constant delay");
    #3.9;
    if (nested_q !== 1 || nested_changes != 2)
      $fatal(1, "Short pulse propagated after a whole-struct assignment");
    if (negative_q !== 1'bx || negative_mixed_q !== 1'bx)
      $fatal(1, "Signed delay was interpreted as an unsigned four-bit value");
    b = 0;
    timing.inner.ticks = 1;
    #3;
    mixed_delay.rise = 2;
    mixed_in = 1'bz;
    #1.9;
    if (nested_q !== 1 || two_q !== 0 || three_q !== 0 || vector_q !== 0)
      $fatal(1, "A fall or turn-off arrived before 32 ns");
    #0.2;
    if (nested_q !== 0 || nested_changes != 3 || two_q !== 1'bz
        || three_q !== 0 || vector_q !== 0)
      $fatal(1, "Fall or two-delay minimum did not arrive after 32 ns");
    #3.8;
    if (three_q !== 0 || vector_q !== 0)
      $fatal(1, "Explicit turn-off arrived before 36 ns");
    #0.2;
    if (three_q !== 1'bz || vector_q !== 2'bzz)
      $fatal(1, "Explicit turn-off did not arrive after 36 ns");
    $display("PASS");
    $finish(0);
  end
endmodule

`timescale 1ps/1ps
module issue3499_fine_precision;
endmodule
