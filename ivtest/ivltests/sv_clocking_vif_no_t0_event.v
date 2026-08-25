// IEEE 1800-2023 14.10: a clocking-block event occurs only when the
// block's specified clocking event is processed.  Compiler-generated VIF
// event identity must therefore be initialized without manufacturing a
// time-zero @(vif.cb) wakeup.
//
// Put the waiter on the compiler's initialization queue so this pins the
// ordering in which it is already armed when hidden synchronization state is
// initialized, independently of ordinary source-order scheduling.
`timescale 1ns/1ps

interface clocking_vif_no_t0_if(input logic clk);
  clocking cb @(posedge clk);
`ifdef CLOCKING_T0_POPULATED_CONTROL
    // Lets this source exercise the older sampled-input tick implementation
    // when run against a baseline compiler.  The committed regression is the
    // itemless form, for which no clocking item may be required.
    input clk;
`endif
  endclocking
endinterface

class clocking_vif_no_t0_waiter;
  virtual clocking_vif_no_t0_if vif;
  int hits = 0;
  time hit_time = '1;

  task run;
    @(vif.cb);
    hit_time = $time;
    hits++;
  endtask
endclass

module sv_clocking_vif_no_t0_event;
  logic clk = 1'b0;
  clocking_vif_no_t0_if bus(clk);
  clocking_vif_no_t0_waiter mon;
  int failures = 0;

  // Put setup on the compiler's initialization queue so this process reaches
  // its event control before ordinary synthesized sampler threads run.  Once
  // it suspends, the remaining initialization/start queues can drain.
  (* _ivl_schedule_init = 1 *)
  initial begin
    mon = new;
    mon.vif = bus;
    mon.run();
  end

  initial begin
    // Drain time-zero Active/Inactive work without advancing time.  Hidden
    // initialization must not look like the declared posedge event.
    #0;
    #0;
    if (mon == null || mon.hits != 0) begin
      failures++;
      $display("FAILED: spurious VIF clocking event at t=0 hits=%0d hit_time=%0t",
               mon == null ? -1 : mon.hits,
               mon == null ? '1 : mon.hit_time);
    end

    // The first real specified event must still wake the already-armed
    // waiter exactly once, and at its actual simulation time.
    #1 clk = 1'b1;
    #1;
    if (mon == null || mon.hits != 1 || mon.hit_time != 1ns) begin
      failures++;
      $display("FAILED: real VIF clocking event hits=%0d hit_time=%0t",
               mon == null ? -1 : mon.hits,
               mon == null ? '1 : mon.hit_time);
    end

    if (failures != 0)
      $fatal(1, "%0d VIF clocking initialization checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
