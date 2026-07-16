// M8 tail T1: buffered output clockvar drives through a VIRTUAL
// interface (IEEE 1800-2017 14.16 + 25.9) — the canonical UVM driver
// pattern:  @(vif.cb); vif.cb.out <= value;
//
// Previously vif.cb.out <= v wrote the raw signal immediately (alias
// model). Now the drive goes through the bound instance's buffered
// machinery, matching the module/instance paths:
//   1. A drive issued after @(vif.cb) — same time step as the event —
//      lands in the current cycle.
//   2. A drive issued between clocking events buffers and lands at
//      the NEXT clocking event (the instance's apply process).
//   3. Last-of-multiple buffered drives wins (14.16.2).
//   4. Direct instance-path state agrees (same buffer variables).

`timescale 1ns/1ns

interface m8d_bus_if(input logic clk);
  logic [7:0] cmd;
  logic       valid;

  clocking cb @(posedge clk);
    output cmd;
    output valid;
  endclocking
endinterface

class m8d_drv;
  virtual m8d_bus_if vif;
  int errors = 0;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  task run_checks;
    // 1: drive after @(vif.cb) lands in the same cycle.
    @(vif.cb);                    // edge at t=5
    vif.cb.cmd <= 8'hA5;
    vif.cb.valid <= 1'b1;
    #1;                           // t=6
    check(vif.cmd == 8'hA5, "same-step vif drive lands this cycle");
    check(vif.valid == 1'b1, "second same-step vif drive lands too");

    // 2: between-edge drive buffers until the next edge.
    #2;                           // t=8, between edges
    vif.cb.cmd <= 8'hB6;
    #1;                           // t=9: must not have landed
    check(vif.cmd == 8'hA5, "between-edge vif drive is buffered");
    @(vif.cb);                    // edge at t=15
    #1;
    check(vif.cmd == 8'hB6, "buffered vif drive lands at the edge");

    // 3: last drive wins.
    #2;                           // t=18
    vif.cb.cmd <= 8'hC1;
    vif.cb.cmd <= 8'hC2;
    @(vif.cb);                    // edge at t=25
    #1;
    check(vif.cmd == 8'hC2, "last of multiple buffered vif drives wins");
  endtask
endclass

module m8_vif_clocking_drive_test;
  logic clk = 0;
  m8d_bus_if bif(clk);
  m8d_drv d;
  int total_errors = 0;

  always #5 clk = ~clk;

  initial begin
    bif.cmd = 8'h00;
    bif.valid = 1'b0;
    d = new;
    d.vif = bif;
    d.run_checks();

    // 4: instance-path drive rides the same machinery.
    #2;
    bif.cb.cmd <= 8'hD3;
    #1;
    if (bif.cmd !== 8'hC2) begin
      total_errors++;
      $display("FAILED: instance-path drive not buffered");
    end
    @(bif.cb);
    #1;
    if (bif.cmd !== 8'hD3) begin
      total_errors++;
      $display("FAILED: instance-path buffered drive did not land");
    end

    total_errors += d.errors;
    if (total_errors == 0)
      $display("PASSED: all m8 vif clocking drive checks");
    else
      $display("FAILED: %0d m8 vif clocking drive checks", total_errors);
    $finish(0);
  end
endmodule
