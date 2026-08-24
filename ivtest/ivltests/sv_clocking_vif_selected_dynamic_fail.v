// A run-time selected VIF clocking output is intentionally rejected until one
// selector can be captured for the buffer, destination, and pending mask.
interface clocking_vif_dynamic_select_if(input logic clk);
  logic [7:0] raw;
  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_vif_selected_dynamic_fail;
  virtual clocking_vif_dynamic_select_if vif;
  integer index = 3;

  initial vif.cb.raw[index] <= 1'b1;
endmodule
