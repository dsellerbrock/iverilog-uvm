// IEEE 1800-2017/2023 14.16: a clocking-block output to a net drives the net
// as an additional driver, resolved with the net's other drivers.
// Reduced from OpenTitan kmac_app_intf.sv:52 and kmac_app_device_driver.sv:38,
// where the procedural write crashed vvp in a part-select driver.
interface app_if(input logic clk);
  logic host_mode = 0;
  logic [7:0] host_rsp = 8'h00;
  wire done;                 // also driven by the concatenation below
  wire [6:0] rest;
  wire lone;                 // driven only by the clocking block
  clocking device_cb @(posedge clk);
    output done, lone;
  endclocking
  assign {done, rest} = host_mode ? host_rsp : 'z;
endinterface

class device_driver;
  virtual app_if vif;
  task drive(bit value);
    vif.device_cb.done <= value;
    vif.device_cb.lone <= ~value;
    @(vif.device_cb);
  endtask
endclass

module test;
  logic clk = 0;
  always #5 clk = ~clk;
  app_if aif(clk);
  device_driver d = new;
  bit failed = 0;

  task automatic check(string what, logic got, logic want);
    if (got !== want) begin
      $display("FAILED %s: got %b want %b", what, got, want);
      failed = 1;
    end
  endtask

  initial begin
    d.vif = aif;
    aif.host_mode = 1;
    aif.host_rsp = 8'h80;
    #1 check("host driver before any clocking drive", aif.done, 1'b1);
    aif.host_mode = 0;
    #1 check("undriven before clocking drive", aif.done, 1'bz);
    @(posedge clk);
    d.drive(1'b1);
    #1;
    check("clocking drive through vif", aif.done, 1'b1);
    check("clocking-only net", aif.lone, 1'b0);
    aif.device_cb.done <= 1'b0;
    @(aif.device_cb);
    #1 check("static clocking drive", aif.done, 1'b0);
    aif.host_mode = 1;           // host drives 1, clocking block drives 0
    #1 check("conflicting drivers resolve to x", aif.done, 1'bx);
    if (!failed) $display("PASSED");
    $finish;
  end
endmodule
