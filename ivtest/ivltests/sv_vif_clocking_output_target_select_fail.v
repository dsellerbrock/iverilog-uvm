// A selected expression as the clocking output's underlying target remains a
// focused unsupported boundary when the clockvar is used through a VIF.
interface target_select_if(input logic clk);
  generate
    if (1) begin : child
      logic [7:0] raw;
    end
  endgenerate
  wire [3:0] nib;

  clocking cb @(posedge clk);
    output nib = child.raw[3:0];
  endclocking
endinterface

module sv_vif_clocking_output_target_select_fail;
  logic clk;
  target_select_if intf(clk);
  virtual target_select_if vif;

  initial begin
    vif = intf;
    vif.cb.nib <= 4'h5;
  end
endmodule
