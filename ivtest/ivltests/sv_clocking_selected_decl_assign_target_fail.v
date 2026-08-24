// A selected clocking declaration-assignment target is legal SystemVerilog.
// Until hidden storage can represent the selected target, Icarus must reject
// its drive rather than write the clockvar proxy with ordinary NBA semantics.
interface clocking_selected_decl_assign_if(input logic clk);
  generate
    if (1) begin : u
      logic [7:0] raw;
    end
  endgenerate
  logic [3:0] nib;

  clocking cb @(posedge clk);
    output nib = u.raw[3:0];
  endclocking
endinterface

module sv_clocking_selected_decl_assign_target_fail;
  logic clk;
  clocking_selected_decl_assign_if bus(clk);

  initial bus.cb.nib <= 4'ha;
endmodule
