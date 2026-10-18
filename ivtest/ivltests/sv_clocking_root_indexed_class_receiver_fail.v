interface clocking_root_indexed_receiver_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;
  logic raw = 1'b0;

  clocking cb @(posedge clk);
    output #2 raw;
  endclocking
endinterface

class clocking_root_indexed_receiver;
  virtual clocking_root_indexed_receiver_if vif;
endclass

module sv_clocking_root_indexed_class_receiver_fail;
  timeunit 1ns;
  timeprecision 1ps;
  logic clk = 1'b0;
  clocking_root_indexed_receiver_if bus0(clk), bus1(clk);
  clocking_root_indexed_receiver roots[2];
  int selector_calls = 0;

  always #5 clk = ~clk;

  function automatic int choose();
    selector_calls += 1;
    return selector_calls - 1;
  endfunction

  initial begin
    roots[0] = new;
    roots[1] = new;
    roots[0].vif = bus0;
    roots[1].vif = bus1;
    roots[choose()].vif.cb.raw <= 1'b1;
    if (selector_calls != 1)
      $fatal(1, "root indexed class receiver evaluated %0d times", selector_calls);
    #6;
    if (bus0.raw !== 1'b0 || bus1.raw !== 1'b0)
      $fatal(1, "root indexed receiver ignored output skew: %b %b",
             bus0.raw, bus1.raw);
    #2;
    if (bus0.raw !== 1'b1 || bus1.raw !== 1'b0)
      $fatal(1, "root indexed class receiver drove wrong interface: %b %b",
             bus0.raw, bus1.raw);
    $display("PASSED");
    $finish;
  end
endmodule
