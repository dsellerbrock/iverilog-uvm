interface clocking_unpacked_bad_pattern_if(input logic clk);
  logic [7:0] raw [0:1];

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_unpacked_output_bad_pattern_fail;
  logic clk = 1'b0;
  clocking_unpacked_bad_pattern_if bus(clk);

  initial bus.cb.raw <= '{8'h12};
endmodule
