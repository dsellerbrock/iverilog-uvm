`timescale 1ns/1ps

interface nested_clocking_missing_child_if(input logic clk);
  logic valid;
  clocking mon_cb @(posedge clk);
    input valid;
  endclocking
endinterface

interface nested_clocking_missing_parent_if(input logic clk);
  nested_clocking_missing_child_if child(clk);
endinterface

class nested_clocking_missing_cfg;
  virtual nested_clocking_missing_parent_if vif;
  task watch_child();
    @(vif.child.no_such_cb);
  endtask
endclass

module sv_vif_nested_clocking_event_missing_fail;
  logic clk = 0;
  nested_clocking_missing_parent_if bus(clk);
  nested_clocking_missing_cfg cfg;
  initial begin
    cfg = new;
    cfg.vif = bus;
    cfg.watch_child();
  end
endmodule
