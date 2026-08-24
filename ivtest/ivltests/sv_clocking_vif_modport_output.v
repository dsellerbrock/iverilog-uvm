// A modport that exports a clocking block authorizes the compiler-generated
// hidden output-buffer state used by drives through a modport-qualified VIF.
`timescale 1ns/1ps

interface mp_clocking_output_if(input logic clk);
  logic raw;

  clocking driver_cb @(posedge clk);
    output raw;
  endclocking

  modport driver_mp(clocking driver_cb);
endinterface

module sv_clocking_vif_modport_output;
  logic clk = 1'b0;
  mp_clocking_output_if bus(clk);
  virtual mp_clocking_output_if.driver_mp vif;
  int failures = 0;

  always #5 clk = ~clk;

  initial begin
    vif = bus;
    bus.raw = 1'b0;

    // A drive issued before the first event uses the generated output buffer
    // and pending flag, even though neither hidden property is a simple
    // member of driver_mp.
    #1 vif.driver_cb.raw <= 1'b1;
    @(vif.driver_cb);
    #1;
    if (bus.raw !== 1'b1) begin
      failures++;
      $display("FAILED buffered modport clocking drive: raw=%b", bus.raw);
    end

    // A drive issued in the clocking event takes the current-event path and
    // reads the generated buffer state back through the same VIF.
    @(vif.driver_cb);
    vif.driver_cb.raw <= 1'b0;
    #1;
    if (bus.raw !== 1'b0) begin
      failures++;
      $display("FAILED current-event modport clocking drive: raw=%b", bus.raw);
    end

    if (failures != 0)
      $fatal(1, "%0d modport clocking-output checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
