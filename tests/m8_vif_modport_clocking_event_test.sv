// IEEE 1800-2017 14.3/25.9: a clocking block exported through a modport
// remains a timing-control event when reached through a virtual interface.
interface m8_modport_cb_if(input logic clk);
  logic data;

  clocking mon_cb @(posedge clk);
    input data;
  endclocking
  modport mon_mp(clocking mon_cb);
endinterface

class m8_modport_cb_monitor;
  virtual m8_modport_cb_if vif;
  int hits;
  time hit_time[3];

  task run();
    repeat (3) begin
      @(vif.mon_mp.mon_cb);
      hit_time[hits] = $time;
      hits++;
    end
  endtask
endclass

module m8_vif_modport_clocking_event_test;
  logic clk = 0;
  m8_modport_cb_if intf(clk);
  m8_modport_cb_monitor mon;

  always #5 clk = ~clk;

  initial begin
    mon = new;
    mon.vif = intf;
    fork
      mon.run();
    join_none

    #31;
    if (mon.hits != 3 || mon.hit_time[0] != 5 ||
        mon.hit_time[1] != 15 || mon.hit_time[2] != 25) begin
      $display("FAILED: modport clocking waits hits=%0d times=%0t,%0t,%0t",
               mon.hits, mon.hit_time[0], mon.hit_time[1], mon.hit_time[2]);
      $finish_and_return(1);
    end

    $display("PASSED: virtual-interface modport clocking waits");
    $finish;
  end
endmodule
