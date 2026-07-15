// M8 increment 2a-4: sampled clocking inputs through a VIRTUAL
// interface (IEEE 1800-2017 14.13 + 25.9).
//
// The interface's clocking block is reached through a class-typed
// handle (vif.cb.sig). Reads of input clockvars route to the hidden
// sample-variable property (resolved by name in the bound instance
// scope); @(vif.cb) maps to an anyedge wait on the sampler's tick
// property, so the process resumes with this edge's samples visible.
//
// Pinned behaviors (mirroring m8_clocking_sample_test.sv):
//   1. vif.cb.in holds the last edge's sample between edges.
//   2. A same-time-step blocking write to the raw signal before the
//      edge is NOT seen by that edge's sample (#1step).
//   3. @(vif.cb) resumes with the fresh sample.
//   4. Direct instance-path reads (bif.cb.sig) agree with the
//      vif reads (same sample variables).

interface m8_bus_if(input logic clk);
  logic [7:0] data;
  logic       valid;

  clocking cb @(posedge clk);
    input data;
    input valid;
  endclocking
endinterface

class m8_mon;
  virtual m8_bus_if vif;
  int errors = 0;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  task run_checks;
    logic [7:0] v;

    // First edge: data stable at 0x11 since time 0.
    @(vif.cb);
    check(vif.cb.data == 8'h11, "vif sample at first edge");
    check(vif.cb.valid == 1'b1, "vif second input sampled too");

    // Raw signal changes mid-cycle; the sample must hold.
    v = vif.cb.data;
    #2;
    check(vif.cb.data == v, "vif sample holds between edges");

    // Next edge picks up the settled value (0x22, set at t=12).
    @(vif.cb);
    check(vif.cb.data == 8'h22, "vif second edge samples settled value");

    // The testbench writes 0x33 in the SAME time step as the third
    // edge, before it: #1step means this edge still samples 0x22.
    @(vif.cb);
    check(vif.cb.data == 8'h22,
          "vif same-step write before edge not sampled (#1step)");

    // And the fourth edge picks it up.
    @(vif.cb);
    check(vif.cb.data == 8'h33, "vif next edge picks up the value");
  endtask
endclass

module m8_vif_clocking_sample_test;
  logic clk = 0;
  m8_bus_if bif(clk);
  m8_mon mon;
  int total_errors = 0;

  always #5 clk = ~clk;

  initial begin
    bif.data  = 8'h11;
    bif.valid = 1'b1;

    mon = new;
    mon.vif = bif;

    fork
      mon.run_checks();
      begin
        // t=12 (after the first edge at t=5... edges: 5,15,25,35):
        // settle 0x22 for the t=15 edge.
        #12 bif.data = 8'h22;
        // t=25 edge: write 0x33 at exactly t=25, before the edge
        // statement can have been processed by the monitor -- the
        // blocking write lands in the same time step as the edge.
        #13 bif.data = 8'h33;
      end
    join

    // 4: direct instance-path read agrees with the vif read
    // (same sample variable underneath).
    if (bif.cb.data !== 8'h33) begin
      total_errors++;
      $display("FAILED: instance-path read disagrees: %h", bif.cb.data);
    end

    total_errors += mon.errors;
    if (total_errors == 0)
      $display("PASSED: all m8 vif clocking sample checks");
    else
      $display("FAILED: %0d m8 vif clocking sample checks", total_errors);
    $finish(0);
  end
endmodule
