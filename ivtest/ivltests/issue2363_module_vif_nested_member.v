// A module-level virtual interface can select a member of a nested interface
// instance (IEEE 1800-2017/2023 25.9).
module main;
  logic clk = 0;
  outer_if o(clk);
  virtual outer_if vif;

  initial begin
    vif = o;
    @(vif.sub.d);
    $display("woke t=%0t d=%b", $time, vif.sub.d);
    $finish;
  end

  initial #12 o.sub.d = 1;
endmodule

interface inner_if(input logic clk);
  logic d = 0;
endinterface

interface outer_if(input logic clk);
  inner_if sub(clk);
endinterface
