// IEEE 1800-2017/2023 25.5, 25.9, 14.3: a modport name selects a view of a
// virtual interface; its exported clocking-block outputs and signals can be
// driven through vif.mp.cb.item and vif.mp.item.
// Reduced from OpenTitan jtag_driver.sv:151 (`HOST_CB.tms <= tms').
interface jtag_like_if;
  logic tck = 0, tms, tdi, trst_n;
  clocking host_cb @(negedge tck);
    output tms, tdi;
  endclocking
  modport host_mp(clocking host_cb, output trst_n);
endinterface

class driver;
  virtual jtag_like_if vif;
  task step(bit tms, bit tdi);
    vif.host_mp.host_cb.tms <= tms;
    vif.host_mp.host_cb.tdi <= tdi;
    @(vif.host_mp.host_cb);
  endtask
  task reset(bit value);
    vif.host_mp.trst_n = value;
  endtask
endclass

module test;
  jtag_like_if jif();
  driver d = new;
  bit failed = 0;
  always #5 jif.tck = ~jif.tck;

  initial begin
    d.vif = jif;
    d.reset(1'b0);
    if (jif.trst_n !== 1'b0) begin $display("FAILED trst_n=%b", jif.trst_n); failed = 1; end
    @(negedge jif.tck);
    d.step(1'b1, 1'b0);
    #1;
    if (jif.tms !== 1'b1 || jif.tdi !== 1'b0) begin
      $display("FAILED tms=%b tdi=%b", jif.tms, jif.tdi);
      failed = 1;
    end
    d.step(1'b0, 1'b1);
    #1;
    if (jif.tms !== 1'b0 || jif.tdi !== 1'b1) begin
      $display("FAILED tms=%b tdi=%b", jif.tms, jif.tdi);
      failed = 1;
    end
    if (!failed) $display("PASSED");
    $finish;
  end
endmodule
