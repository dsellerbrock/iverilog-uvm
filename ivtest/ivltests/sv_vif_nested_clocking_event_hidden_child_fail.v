`timescale 1ns/1ps

interface nested_clocking_hidden_child_if(input logic clk);
  logic valid;
  clocking mon_cb @(posedge clk);
    input valid;
  endclocking
endinterface

interface nested_clocking_hidden_parent_if(input logic clk);
  logic visible;
  nested_clocking_hidden_child_if child(clk);
  modport monitor_mp(input visible);
endinterface

class nested_clocking_hidden_cfg;
  virtual nested_clocking_hidden_parent_if.monitor_mp vif;
  task watch_child();
    @(vif.child.mon_cb);
  endtask
endclass

module sv_vif_nested_clocking_event_hidden_child_fail;
  logic clk = 0;
  always #5 clk = !clk;
  nested_clocking_hidden_parent_if bus(clk);
  nested_clocking_hidden_cfg cfg;
  initial begin
    cfg = new;
    cfg.vif = bus;
    cfg.watch_child();
  end
endmodule
