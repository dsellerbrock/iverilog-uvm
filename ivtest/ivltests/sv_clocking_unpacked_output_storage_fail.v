// An unpacked-array clockvar is legal SystemVerilog. Icarus does not yet have
// representable hidden output-buffer storage for it, so the clocking drive
// must fail loudly instead of falling through to an immediate ordinary NBA.
interface clocking_unpacked_output_if(input logic clk);
  logic raw [0:1];

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_unpacked_output_storage_fail;
  logic clk;
  clocking_unpacked_output_if bus(clk);

  initial bus.cb.raw <= '{1'b1, 1'b0};
endmodule
