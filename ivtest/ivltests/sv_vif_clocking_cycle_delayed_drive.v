// IEEE 1800-2017/2023 14.16: a cycle-delayed clocking drive through a
// class-held virtual interface captures its RHS and returns without waiting.
`timescale 1ns/1ps

interface cycle_drive_if(input logic clk);
  logic [7:0] data = 0;
  logic [7:0] dynamic_data = 0;

  clocking cb @(posedge clk);
    default input #1step output #0;
    output data, dynamic_data;
  endclocking
endinterface

class cycle_drive_driver;
  virtual cycle_drive_if vif;
  logic [7:0] value;
  int cycle_count;
  bit returned;

  function new(virtual cycle_drive_if vif);
    this.vif = vif;
  endfunction

  task drive();
    @(vif.cb);
    vif.cb.data <= ##2 value;
    vif.cb.dynamic_data <= ##cycle_count value;
    returned = 1;
  endtask
endclass

module sv_vif_clocking_cycle_delayed_drive;
  logic clk = 0;
  cycle_drive_if bus(clk);
  cycle_drive_driver driver;
  int errors = 0;
  cycle_drive_reactive_check region_check(clk, bus.data, bus.dynamic_data);
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
    driver.cycle_count = 2;
    driver.drive();
    check(driver.returned, "cycle-delayed VIF drive returns at issue time");
    driver.value = 8'hff;
    check(bus.data === 8'h00, "cycle-delayed drive does not update immediately");
    check(bus.dynamic_data === 8'h00, "variable cycle delay does not update immediately");

    @(posedge clk); #1;
    check(bus.data === 8'h00, "##2 drive remains pending after one edge");
    check(bus.dynamic_data === 8'h00, "##cycle_count drive remains pending after one edge");
    @(posedge clk); #0;
    check(bus.data === 8'h00, "##2 drive waits for the NBA region at edge two");
    check(bus.dynamic_data === 8'h00, "##cycle_count drive waits for the NBA region at edge two");
    #1;
    check(bus.data === 8'h3c, "##2 drive lands with the captured RHS after two edges");
    check(bus.dynamic_data === 8'h3c, "##cycle_count drive lands with the captured RHS after two edges");

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

program cycle_drive_reactive_check(input logic clk,
                                   input logic [7:0] data,
                                   input logic [7:0] dynamic_data);
  initial begin
    repeat (3) @(posedge clk);
    if (data !== 8'h00 || dynamic_data !== 8'h00)
      $fatal(1, "cycle-delayed drive was visible in Reactive: data=%h dynamic_data=%h",
             data, dynamic_data);
    #2; // IEEE 1800-2017/2023 §9.6.1 ends simulation when all program blocks finish.
  end
endprogram
