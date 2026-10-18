interface clocking_indexed_receiver_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;
  logic raw = 1'b0;

  clocking cb @(posedge clk);
    output #2 raw;
  endclocking
endinterface

class clocking_indexed_receiver_leaf;
  virtual clocking_indexed_receiver_if vif;
endclass

class clocking_indexed_receiver_root;
  clocking_indexed_receiver_leaf leaves[2];
endclass

module sv_clocking_indexed_class_receiver_fail;
  timeunit 1ns;
  timeprecision 1ps;
  logic clk = 1'b0;
  clocking_indexed_receiver_if bus0(clk), bus1(clk);
  clocking_indexed_receiver_root root;
  int selector_calls = 0;

  always #5 clk = ~clk;

  function automatic int choose_leaf();
    selector_calls++;
    return selector_calls - 1;
  endfunction

  initial begin
    root = new;
    root.leaves[0] = new;
    root.leaves[1] = new;
    root.leaves[0].vif = bus0;
    root.leaves[1].vif = bus1;
    root.leaves[choose_leaf()].vif.cb.raw <= 1'b1;
    if (selector_calls != 1)
      $fatal(1, "indexed class receiver evaluated %0d times", selector_calls);
    #6;
    if (bus0.raw !== 1'b0 || bus1.raw !== 1'b0)
      $fatal(1, "indexed class receiver ignored output skew: %b %b",
             bus0.raw, bus1.raw);
    #2;
    if (bus0.raw !== 1'b1 || bus1.raw !== 1'b0)
      $fatal(1, "indexed class receiver drove wrong interface: %b %b",
             bus0.raw, bus1.raw);
    $display("PASSED");
    $finish;
  end
endmodule
