interface clocking_static_overlap_if(input logic clk);
  logic source, final_value;
  assign final_value = source;
  clocking sender_cb @(posedge clk);
    output final_value;
  endclocking
endinterface

module sv_clocking_output_continuous_static_overlap;
  logic clk;
  clocking_static_overlap_if bus(clk);
  initial bus.sender_cb.final_value <= 1'b1;
endmodule
