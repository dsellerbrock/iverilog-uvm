// Writes that a modport view does not allow, and writes to members that
// do not exist, are errors rather than silently dropped assignments.
interface view_if;
  logic clk = 0, req, ack;
  clocking host_cb @(posedge clk); output req; endclocking
  clocking dev_cb @(posedge clk); output ack; endclocking
  modport host_mp(clocking host_cb, input ack);
endinterface

class bad_driver;
  virtual view_if vif;
  task run();
    vif.host_mp.ack = 1'b1;            // input in this modport
    vif.host_mp.dev_cb.ack <= 1'b1;    // clocking block not exported
    vif.no_such_member = 1'b1;         // unknown member
  endtask
endclass

module test;
  bad_driver d = new;
endmodule
