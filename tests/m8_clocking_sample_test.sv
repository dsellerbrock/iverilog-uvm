// M8 increment 2a: sampled clocking-block inputs (IEEE 1800-2017 14.13).
//
// Replaces the alias model for input clockvars: `cb.sig` with input
// direction now reads the value SAMPLED at the most recent clocking
// event with the default #1step skew (the Preponed-region value of
// the edge time step), not the live signal.
//
// Pinned behaviors:
//   1. Between edges, cb.in holds the last edge's sample even after
//      the raw signal changes.
//   2. A blocking write to the raw signal in the SAME time step as
//      the edge (before the edge statement executes) is NOT seen by
//      that edge's sample -- #1step samples the value from the end
//      of the previous time step (the classic testbench race the
//      alias model lost).
//   3. Processes woken by @(cb) observe the fresh sample of that
//      edge deterministically (the sampler triggers the @(cb) event
//      after updating).
//   4. inout clockvars sample on read too.
//   5. Before the first clocking event, cb.in reads X -- no sample
//      has been taken yet (matches common commercial behavior).

module m8_clocking_sample_test;
  logic clk = 0;
  logic [7:0] din = 8'h11;
  logic [7:0] dio = 8'h21;
  logic [7:0] dout;

  clocking cb @(posedge clk);
    input  din;
    inout  dio;
    output dout;
  endclocking

  int errors = 0;
  logic [7:0] woke_val;
  int woke_count = 0;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  // Check 3: an @(cb) reader always sees the sample of the edge that
  // woke it.
  always @(cb) begin
    woke_val = cb.din;
    woke_count++;
  end

  initial begin
    // Check 5: no edge has happened yet -- no sample taken, reads X.
    check($isunknown(cb.din), "pre-edge read is X (no sample yet)");

    // First edge at t=10: din stable at 0x11 since t=0.
    #10 clk = 1;
    #1;
    check(cb.din == 8'h11, "sample at first edge");
    check(woke_count == 1 && woke_val == 8'h11,
          "@(cb) reader woke with fresh sample");

    // Change din mid-cycle: the sample must NOT follow it.
    #2 din = 8'h22;
    #1;
    check(cb.din == 8'h11, "between edges holds last sample");
    check(din == 8'h22, "raw signal did change");

    // Second edge at t=20: din has been 0x22 since t=13.
    #6 clk = 0;
    #10 clk = 1;
    #1;
    check(cb.din == 8'h22, "second edge samples settled value");
    check(woke_count == 2 && woke_val == 8'h22,
          "@(cb) reader woke with second sample");

    // Third edge with a SAME-TIMESTEP blocking write before the
    // edge: #1step means the sample is the value from the end of
    // the PREVIOUS time step, so the write is not seen.
    #9 clk = 0;
    #10;
    din = 8'h33;   // same time step as the edge below
    clk = 1;       // edge fires in this same time step
    #1;
    check(cb.din == 8'h22, "same-step write before edge not sampled (#1step)");
    check(woke_val == 8'h22, "@(cb) reader saw #1step sample too");
    check(din == 8'h33, "raw signal has the new value");

    // Next edge samples it.
    #9 clk = 0;
    #10 clk = 1;
    #1;
    check(cb.din == 8'h33, "next edge picks up the value");

    // Check 4: inout clockvar reads are sampled.
    dio = 8'h44;
    #1;
    check(cb.dio == 8'h21, "inout read holds last sample");
    #8 clk = 0;
    #10 clk = 1;
    #1;
    check(cb.dio == 8'h44, "inout read updates at edge");

    // Output clockvar keeps the alias model until 2b (drives land
    // on the raw signal immediately through the existing path).
    dout = 8'h55;
    check(dout == 8'h55, "output clockvar alias write still works");

    if (errors == 0)
      $display("PASSED: all m8 clocking sample checks");
    else
      $display("FAILED: %0d m8 clocking sample checks", errors);
    $finish(0);
  end
endmodule
