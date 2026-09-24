`timescale 1ns/1ps

interface clocking_disjoint_if(input logic clk);
  logic source, final_value, drive, alias_target;
  logic \_ivl_obogus ;
  assign final_value = source;

  clocking sender_cb @(posedge clk);
    output drive;
    output alias_sig = alias_target;
  endclocking
  clocking monitor_cb @(posedge clk);
    input final_value;
  endclocking
  modport DRIVER(clocking sender_cb);
endinterface

class plain_driver;
  virtual clocking_disjoint_if vif;
  task run();
    vif.sender_cb.drive <= 1'b1;
    vif.sender_cb.alias_sig <= 1'b1;
    vif.\_ivl_obogus = 1'b1;
  endtask
  task unused();
    vif.sender_cb.drive <= 1'b0;
  endtask
endclass

class modport_driver;
  virtual clocking_disjoint_if.DRIVER vif;
  task run();
    vif.sender_cb.drive <= 1'b1;
  endtask
endclass

module sv_clocking_output_continuous_disjoint;
  logic clk = 0;
  clocking_disjoint_if first(clk), second(clk);
  plain_driver p;
  modport_driver m;
  bit choose;

  always #5 clk = ~clk;

  initial begin
    first.source = 1'b0;
    second.source = 1'b1;
    choose = $test$plusargs("first_receiver");
    p = new();
    m = new();
    if (choose) p.vif = first;
    else p.vif = second;
    m.vif = first;
    #1;
    p.run();
    m.run();
    @(posedge clk);
    #1;
    if (first.final_value !== 1'b0 || second.final_value !== 1'b1)
      $fatal(1, "continuous final value changed");
    if (first.drive !== 1'b1)
      $fatal(1, "modport clocking drive did not land");
    if (choose && (first.alias_target !== 1'b1 || first.drive !== 1'b1))
      $fatal(1, "selected first receiver drive did not land");
    if (!choose && (second.alias_target !== 1'b1 || second.drive !== 1'b1))
      $fatal(1, "selected second receiver drive did not land");
    if (choose && first.\_ivl_obogus !== 1'b1)
      $fatal(1, "ordinary generated-looking property write did not land");
    if (!choose && second.\_ivl_obogus !== 1'b1)
      $fatal(1, "ordinary generated-looking property write did not land");
    $display("PASSED");
    $finish;
  end
endmodule
