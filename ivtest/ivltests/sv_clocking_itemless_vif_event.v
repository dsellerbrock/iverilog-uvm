// An itemless interface clocking block remains an event through both a plain
// virtual-interface handle and a modport-qualified handle.  No clocking input
// or output declaration may be required to create the event identity.
`timescale 1ns/1ps

interface itemless_vif_if(input logic clk);
  int nba_stage1;
  int nba_stage2;

  clocking cb @(posedge clk);
  endclocking

  modport monitor_mp(clocking cb, input nba_stage1, nba_stage2);
endinterface

class itemless_plain_monitor;
  virtual itemless_vif_if vif;
  int hits = 0;
  time hit_time[3];
  int hit_stage1[3];
  int hit_stage2[3];

  task run;
    repeat (3) begin
      @(vif.cb);
      hit_time[hits] = $time;
      hit_stage1[hits] = vif.nba_stage1;
      hit_stage2[hits] = vif.nba_stage2;
      hits++;
    end
  endtask
endclass

class itemless_modport_monitor;
  virtual itemless_vif_if.monitor_mp vif;
  int hits = 0;
  time hit_time[3];
  int hit_stage1[3];
  int hit_stage2[3];

  task run;
    repeat (3) begin
      @(vif.cb);
      hit_time[hits] = $time;
      hit_stage1[hits] = vif.nba_stage1;
      hit_stage2[hits] = vif.nba_stage2;
      hits++;
    end
  endtask
endclass

module sv_clocking_itemless_vif_event;
  logic clk = 1'b0;
  itemless_vif_if bus(clk);
  itemless_plain_monitor plain_mon;
  itemless_modport_monitor modport_mon;
  int failures = 0;

  always #5 clk = ~clk;

  always @(posedge clk)
    bus.nba_stage1 <= bus.nba_stage1 + 1;

  always @(bus.nba_stage1)
    bus.nba_stage2 <= bus.nba_stage1;

  initial begin
    plain_mon = new;
    modport_mon = new;
    bus.nba_stage1 = 0;
    bus.nba_stage2 = 0;
    plain_mon.vif = bus;
    modport_mon.vif = bus;

    fork
      plain_mon.run();
      modport_mon.run();
    join_none

    #31;
    if (plain_mon.hits != 3 || plain_mon.hit_time[0] != 5 ||
        plain_mon.hit_time[1] != 15 || plain_mon.hit_time[2] != 25 ||
        plain_mon.hit_stage1[0] != 1 || plain_mon.hit_stage2[0] != 1 ||
        plain_mon.hit_stage1[1] != 2 || plain_mon.hit_stage2[1] != 2 ||
        plain_mon.hit_stage1[2] != 3 || plain_mon.hit_stage2[2] != 3) begin
      failures++;
      $display("FAILED plain itemless VIF hits=%0d times=%0t,%0t,%0t stages=%0d/%0d,%0d/%0d,%0d/%0d",
               plain_mon.hits, plain_mon.hit_time[0], plain_mon.hit_time[1],
               plain_mon.hit_time[2], plain_mon.hit_stage1[0],
               plain_mon.hit_stage2[0], plain_mon.hit_stage1[1],
               plain_mon.hit_stage2[1], plain_mon.hit_stage1[2],
               plain_mon.hit_stage2[2]);
    end
    if (modport_mon.hits != 3 || modport_mon.hit_time[0] != 5 ||
        modport_mon.hit_time[1] != 15 || modport_mon.hit_time[2] != 25 ||
        modport_mon.hit_stage1[0] != 1 || modport_mon.hit_stage2[0] != 1 ||
        modport_mon.hit_stage1[1] != 2 || modport_mon.hit_stage2[1] != 2 ||
        modport_mon.hit_stage1[2] != 3 || modport_mon.hit_stage2[2] != 3) begin
      failures++;
      $display("FAILED modport itemless VIF hits=%0d times=%0t,%0t,%0t stages=%0d/%0d,%0d/%0d,%0d/%0d",
               modport_mon.hits, modport_mon.hit_time[0],
               modport_mon.hit_time[1], modport_mon.hit_time[2],
               modport_mon.hit_stage1[0], modport_mon.hit_stage2[0],
               modport_mon.hit_stage1[1], modport_mon.hit_stage2[1],
               modport_mon.hit_stage1[2], modport_mon.hit_stage2[2]);
    end

    if (failures != 0)
      $fatal(1, "%0d itemless virtual-interface checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
