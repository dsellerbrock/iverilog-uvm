interface clocking_same_scope_overlap_if(input logic clk);
  logic source, final_value;
  assign final_value = source;
  clocking sender_cb @(posedge clk);
    output final_value;
  endclocking
  initial sender_cb.final_value <= 1'b1;
endinterface

module sv_clocking_output_continuous_same_scope_overlap;
  logic clk;
  clocking_same_scope_overlap_if bus(clk);
endmodule
