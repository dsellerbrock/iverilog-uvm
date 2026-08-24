// IEEE 1800-2017 14.16 and 10.4.2: a nonblocking assignment to a
// selected packed member of a clocking output updates only that member.
// Untouched fields retain their value for both current-event and buffered
// virtual-interface drives.
`timescale 1ns/1ps

interface partial_member_if(input logic clk);
  typedef struct packed {
    logic       valid;
    logic [3:0] payload;
    logic       ready;
  } bus_t;

  bus_t raw;
  wire bus_t bus;

  clocking cb @(posedge clk);
    output bus = raw;
  endclocking
endinterface

class partial_member_driver;
  virtual partial_member_if vif;

  task drive_ready_at_event(logic value);
    @(vif.cb);
    vif.cb.bus.ready <= value;
  endtask

  task drive_valid_at_event(logic value);
    @(vif.cb);
    vif.cb.bus.valid <= value;
  endtask
endclass

module sv_vif_clocking_partial_member_preserve;
  logic clk = 1'b0;
  partial_member_if intf(clk);
  partial_member_driver drv;
  int failures = 0;

  initial repeat (10) #5 clk = ~clk;

  task check(input logic [5:0] expected, input string label_text);
    if (intf.raw !== expected) begin
      failures++;
      $display("FAILED %s raw=%b expected=%b", label_text, intf.raw,
               expected);
    end
  endtask

  initial begin
    drv = new;
    drv.vif = intf;

    // A drive after @(cb) lands in this event's NBA processing. Only ready
    // may change; the output buffer has never initialized the other fields.
    intf.raw = 6'b1_1010_0;
    fork
      drv.drive_ready_at_event(1'b1);
    join_none
    #6;
    check(6'b1_1010_1, "same-event member drive");

    // A between-event drive is held until the next clocking event, again
    // without replacing fields that were not selected by the assignment.
    #2;
    intf.raw = 6'b1_0101_1;
    drv.vif.cb.bus.ready <= 1'b0;
    #1;
    check(6'b1_0101_1, "buffered member drive landed early");
    #7;
    check(6'b1_0101_0, "buffered member drive");

    // A drive issued after the event supersedes an older buffered drive to
    // the same member when both mature in the same event.
    #2;
    intf.raw = 6'b1_1010_1;
    drv.vif.cb.bus.ready <= 1'b0;
    fork
      drv.drive_ready_at_event(1'b1);
    join_none
    #8;
    check(6'b1_1010_1, "same-member clocking ordering");

    // Disjoint buffered/current-event member drives merge.
    #2;
    intf.raw = 6'b0_0011_0;
    drv.vif.cb.bus.payload <= 4'b1100;
    fork
      drv.drive_valid_at_event(1'b1);
    join_none
    #8;
    check(6'b1_1100_0, "disjoint member merge");

    // An ordinary NBA to an untouched sibling in the edge slot must survive
    // the clocking drive's selected Re-NBA-like update.
    #2;
    intf.raw = 6'b0_0011_0;
    drv.vif.cb.bus.ready <= 1'b1;
    fork
      begin
        @(posedge clk);
        intf.raw.payload <= 4'b1010;
      end
    join_none
    #8;
    check(6'b0_1010_1, "ordinary sibling NBA merge");

    if (failures != 0) begin
      $fatal(1, "%0d partial member checks failed", failures);
    end
    $display("PASSED");
  end
endmodule
