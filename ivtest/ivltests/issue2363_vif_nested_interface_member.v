module tb;
  logic clk = 0;
  outer_if o(clk);
  virtual outer_if vif;
  initial begin
    vif = o;
    @(vif.sub.d);
    $display("woke t=%0t d=%b", $time, vif.sub.d);
    $display("PASSED");
    $finish(0);
  end
  initial #12 o.sub.d = 1;
endmodule

interface inner_if(input logic clk);
  logic d = 0;
endinterface

interface outer_if(input logic clk);
  inner_if sub(clk);
endinterface
