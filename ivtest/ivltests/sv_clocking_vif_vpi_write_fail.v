// VPI-backed output arguments must not bypass clocking sampling, clocking
// output buffering, or a modport's input direction. Until those writes can be
// represented losslessly, reject them loudly and leave every target unchanged.
interface clocking_vif_vpi_write_if(input logic clk);
  logic clocking_input_raw;
  logic clocking_output_raw;
  logic modport_input_raw;

  clocking cb @(posedge clk);
    input #0 clocking_input_raw;
    output clocking_output_raw;
  endclocking

  modport monitor_mp(input modport_input_raw);
endinterface

module sv_clocking_vif_vpi_write_fail;
  logic clk = 1'b0;
  clocking_vif_vpi_write_if bus(clk);
  virtual clocking_vif_vpi_write_if vif;
  virtual clocking_vif_vpi_write_if.monitor_mp monitor_vif;
  int matched;

  initial begin
    bus.clocking_input_raw = 1'b0;
    bus.clocking_output_raw = 1'b0;
    bus.modport_input_raw = 1'b0;
    vif = bus;
    monitor_vif = bus;

    #5 clk = 1'b1;
  end

  initial begin
    @(vif.cb);
    matched += $value$plusargs("CBIN=%b", vif.cb.clocking_input_raw);
    matched += $value$plusargs("CBOUT=%b", vif.cb.clocking_output_raw);
    matched += $value$plusargs("MPIN=%b", monitor_vif.modport_input_raw);

    if (matched != 3)
      $fatal(1, "plusargs were not matched: %0d", matched);
    if (vif.cb.clocking_input_raw !== 1'b0)
      $fatal(1, "clocking input sample was mutated: %b",
             vif.cb.clocking_input_raw);
    if (bus.clocking_output_raw !== 1'b0)
      $fatal(1, "clocking output bypassed its drive path: %b",
             bus.clocking_output_raw);
    if (bus.modport_input_raw !== 1'b0)
      $fatal(1, "modport input was mutated: %b", bus.modport_input_raw);

    $display("matched=%0d values unchanged", matched);
    // Natural simulation end preserves the nonzero status set by the three
    // loud VPI-write rejections; $finish would overwrite that status.
  end
endmodule
