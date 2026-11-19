`timescale 1ns/100ps

module issue3497;
  logic a = 0;
  int dv = 3;
  wire z, k;
  assign #dv z = a;
  assign #3 k = a;

  int control = 7;
  int mask = 3;
  logic computed_rhs = 0;
  wire computed_z;
  assign #(control & mask) computed_z = computed_rhs;

  realtime fractional_delay = 1.26;
  real real_rhs = 2.5;
  wire real real_z;
  wire weak_z;
  assign #fractional_delay real_z = real_rhs;
  assign (weak0, weak1) #fractional_delay weak_z = a;

  logic two_rhs = 0;
  wire two_z;
  assign #(1, dv) two_z = two_rhs;

  logic [1:0] vector_rhs = 2'b01;
  wire [1:0] vector_z;
  assign #dv vector_z = vector_rhs;

  logic pulse_rhs = 0;
  int pulse_delay = 3;
  int pulse_mask = 15;
  wire pulse_z;
  assign #(pulse_delay & pulse_mask) pulse_z = pulse_rhs;

  logic live_rhs = 0;
  int live_delay = 3;
  wire live_z;
  assign #live_delay live_z = live_rhs;

  initial begin
    live_delay = 4;
    live_rhs = 1;
  end

  initial begin
    // Let the initial transition become pending before replacing it.
    #0;
    pulse_delay = 5;
    pulse_rhs = 1;
    #1 pulse_delay = 8; // A delay-only write does not retime that transition.
  end

  initial begin
    #1;
    if (z !== 1'bx || k !== 1'bx || computed_z !== 1'bx ||
        two_z !== 1'bx || vector_z !== 2'bxx || pulse_z !== 1'bx)
      $fatal(1, "early update at 1 ns: z=%b k=%b computed=%b two=%b vector=%b pulse=%b",
             z, k, computed_z, two_z, vector_z, pulse_z);

    #0.2;
    if (real_z != 0.0 || weak_z !== 1'bx)
      $fatal(1, "fractional delay propagated before 1.3 ns");
    #0.1;
    #0;
    if (real_z != 2.5 || $sformatf("%v", weak_z) != "We0")
      $fatal(1, "fractional delay at 1.3 ns: real=%g weak=%v", real_z, weak_z);

    #1.6;
    if (z !== 1'bx || k !== 1'bx || computed_z !== 1'bx ||
        two_z !== 1'bx || vector_z !== 2'bxx)
      $fatal(1, "update before 3 ns");
    #0.1;
    #0;
    if (z !== 1'b0 || k !== 1'b0 || computed_z !== 1'b0 ||
        two_z !== 1'b0 || vector_z !== 2'b01)
      $fatal(1, "missing 3 ns update: z=%b k=%b computed=%b two=%b vector=%b",
             z, k, computed_z, two_z, vector_z);
    if (pulse_z !== 1'bx || live_z !== 1'bx)
      $fatal(1, "superseded transition reached the output at 3 ns");
    two_rhs = 1'bz;

    #0.9;
    if (two_z !== 1'b0)
      $fatal(1, "turn-off transition arrived before the minimum delay");
    #0.1;
    #0;
    if (two_z !== 1'bz)
      $fatal(1, "turn-off transition missed the 1 ns minimum delay");
    if (live_z !== 1'b1)
      $fatal(1, "time-zero Active write did not reach the output at 4 ns");

    #0.9;
    if (pulse_z !== 1'bx)
      $fatal(1, "replacement transition arrived before 5 ns");
    #0.1;
    #0;
    if (pulse_z !== 1'b1)
      $fatal(1, "replacement transition missed 5 ns");
    $display("PASS");
  end
endmodule
