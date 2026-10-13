// NEG-DIAG: selected local-variable match-item assignments currently require a fixed-delay sequence.
module sva_match_item_selected_variable_delay;
  logic clk;
  default clocking cb @(posedge clk); endclocking

  property p;
    logic [7:0] acc;
    (1'b1, acc[3:0] = 4'h5) ##[1:2] (acc == 8'h05);
  endproperty

  assert property (p);
endmodule
