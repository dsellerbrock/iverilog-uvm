// IEEE 1800-2017 14.16 and 10.4.2: constant bit/part selects on a
// virtual-interface clocking output retain the selected raw destination.
`timescale 1ns/1ps

interface partial_select_if(input logic clk);
  logic [7:0] raw;
  wire [7:0] bus;

  clocking cb @(posedge clk);
    output bus = raw;
  endclocking
endinterface

class partial_select_driver;
  virtual partial_select_if vif;

  task drive_bit_at_event(logic value);
    @(vif.cb);
    vif.cb.bus[3] <= value;
  endtask
endclass

module sv_vif_clocking_partial_select_preserve;
  logic clk = 1'b0;
  partial_select_if intf(clk);
  partial_select_driver drv;
  int failures = 0;

  initial repeat (4) #5 clk = ~clk;

  task check(input logic [7:0] expected, input string label_text);
    if (intf.raw !== expected) begin
      failures++;
      $display("FAILED %s raw=%b expected=%b", label_text, intf.raw,
               expected);
    end
  endtask

  initial begin
    drv = new;
    drv.vif = intf;

    intf.raw = 8'b1010_0101;
    fork
      drv.drive_bit_at_event(1'b1);
    join_none
    #6;
    check(8'b1010_1101, "same-event bit drive");

    #2;
    intf.raw = 8'b1001_0110;
    drv.vif.cb.bus[6:5] <= 2'b11;
    #1;
    check(8'b1001_0110, "buffered part drive landed early");
    #7;
    check(8'b1111_0110, "buffered part drive");

    if (failures != 0) begin
      $fatal(1, "%0d partial select checks failed", failures);
    end
    $display("PASSED");
  end
endmodule
