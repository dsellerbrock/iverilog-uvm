interface clocking_unpacked_net_output_if(input logic clk);
  uwire [7:0] raw [0:1];

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_unpacked_net_output_fail;
  logic clk = 1'b0;
  clocking_unpacked_net_output_if bus(clk);
endmodule
