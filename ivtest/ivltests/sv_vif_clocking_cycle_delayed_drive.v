// IEEE 1800-2017/2023 14.16: a cycle-delayed clocking drive through a
// class-held virtual interface captures its RHS and returns without waiting.
`timescale 1ns/1ps

interface cycle_drive_if(input logic clk);
  logic [7:0] data = 0;

  clocking cb @(posedge clk);
    default input #1step output #0;
    output data;
  endclocking
endinterface

class cycle_drive_driver;
  virtual cycle_drive_if vif;
  logic [7:0] value;
  bit returned;

  function new(virtual cycle_drive_if vif);
    this.vif = vif;
  endfunction

  task drive();
    @(vif.cb);
    vif.cb.data <= ##2 value;
    returned = 1;
  endtask
endclass

module sv_vif_clocking_cycle_delayed_drive;
  logic clk = 0;
  cycle_drive_if bus(clk);
  cycle_drive_driver driver;
  int errors = 0;

  always #5 clk = ~clk;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    driver = new(bus);
    driver.value = 8'h3c;
    driver.drive();
    check(driver.returned, "cycle-delayed VIF drive returns at issue time");
    driver.value = 8'hff;
    check(bus.data === 8'h00, "cycle-delayed drive does not update immediately");

    @(posedge clk); #1;
    check(bus.data === 8'h00, "##2 drive remains pending after one edge");
    @(posedge clk); #1;
    check(bus.data === 8'h3c, "##2 drive lands with the captured RHS after two edges");

    if (errors != 0)
      $fatal(1, "%0d virtual-interface cycle-drive checks failed", errors);
    $display("PASSED");
    $finish;
  end

  initial begin
    #100;
    $fatal(1, "virtual-interface cycle-drive watchdog expired");
  end
endmodule
