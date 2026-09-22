interface vif_function_dependency_if;
  logic [1:0] data;
  logic sel;
endinterface

class vif_function_dependency_cfg;
  virtual vif_function_dependency_if vif;
  function automatic int selector();
    return vif.sel;
  endfunction
endclass

class vif_function_dependency_dev;
  vif_function_dependency_cfg cfg;
  int wakes;
  task automatic wait_pos;
    @(posedge cfg.vif.data[cfg.selector()]);
    wakes++;
  endtask
endclass

module vif_function_dependency;
  vif_function_dependency_if bus_a(), bus_b();
  vif_function_dependency_dev d;
  initial begin
    bus_a.data = 2'b10; bus_a.sel = 1'b0;
    bus_b.data = 2'b10; bus_b.sel = 1'b0;
    d = new; d.cfg = new; d.cfg.vif = bus_a;
    fork: first_wait d.wait_pos(); join_none
    fork: timeout_guard begin
      #40 $fatal(1, "VIF function dependency test timed out");
    end join_none

    #1 bus_a.data[1] = 1'b1;
    #1 if (d.wakes != 0) $fatal(1, "unselected data change woke waiter");
    d.cfg.vif.sel = 1'b1;
    #1 if (d.wakes != 1) $fatal(1, "VIF selector change missed selected edge");

    bus_a.data = 2'b00; bus_a.sel = 1'b0;
    fork: second_wait d.wait_pos(); join_none
    #1 d.cfg.vif = bus_b;
    #1 bus_a.data[0] = 1'b1;
    #1 if (d.wakes != 1) $fatal(1, "old VIF source woke after equal-value rebind");
    bus_b.data[0] = 1'b1;
    #1 if (d.wakes != 2) $fatal(1, "new VIF source did not deliver selected edge");
    $display("PASS VIF function dependency");
    $finish;
  end
endmodule
