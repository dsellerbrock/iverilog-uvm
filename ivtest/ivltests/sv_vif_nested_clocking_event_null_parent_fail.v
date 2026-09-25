`timescale 1ns/1ps

interface nested_clocking_null_child_if(input logic clk);
  logic valid;
  clocking mon_cb @(posedge clk);
    input valid;
  endclocking
endinterface

interface nested_clocking_null_parent_if(input logic clk);
  nested_clocking_null_child_if child(clk);
endinterface

class nested_clocking_null_cfg;
  virtual nested_clocking_null_parent_if vif;
endclass

class nested_clocking_null_monitor;
  nested_clocking_null_cfg cfg;
  function new(nested_clocking_null_cfg c);
    cfg = c;
  endfunction
  task watch_child();
    @(cfg.vif.child.mon_cb);
    $fatal(1, "nested event wait returned through null parent");
  endtask
endclass

module sv_vif_nested_clocking_event_null_parent_fail;
  nested_clocking_null_cfg cfg;
  nested_clocking_null_monitor mon;
  initial begin
    cfg = new;
    cfg.vif = null;
    mon = new(cfg);
    fork mon.watch_child(); join_none
    #1;
    $fatal(1, "null nested clocking event was not fatal");
  end
endmodule
