// IEEE 1800-2017/2023 14.3 and 14.16: a selected hierarchical output
// clockvar target inside a generate block is driven through a VIF.
`timescale 1ns/1ns

interface generate_part_select_if(input logic clk);
  if (1) begin : child
    logic [7:0] raw = 8'hc3;
  end
  clocking cb @(posedge clk);
    output nib = child.raw[3:0];
  endclocking
endinterface

module sv_vif_clocking_generate_part_select;
  logic clk = 0;
  generate_part_select_if u(clk);
  virtual generate_part_select_if vif;
  initial forever #5 clk = ~clk;
  initial begin
    vif = u;
    #1 vif.cb.nib <= 4'h5;
    #5;
    if (u.child.raw !== 8'hc5)
      $fatal(1, "generate-block clockvar drive failed: raw=%h", u.child.raw);
    $display("PASSED");
    $finish;
  end
endmodule
