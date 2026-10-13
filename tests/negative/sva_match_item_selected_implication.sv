// NEG-DIAG: selected local-variable match-item assignments in implications are not yet supported.
module sva_match_item_selected_implication;
  logic clk;
  default clocking cb @(posedge clk); endclocking

  property p;
    logic [7:0] acc;
    (1'b1, acc[3:0] = 4'h5) |-> (acc == 8'h05);
  endproperty

  assert property (p);
endmodule
