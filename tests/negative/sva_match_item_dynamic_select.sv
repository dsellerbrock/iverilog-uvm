// NEG-DIAG: requires a constant bit-select index.
module sva_match_item_dynamic_select;
  property p;
    logic [7:0] acc;
    int index;
    (1'b1, acc[index] = 1'b1);
  endproperty
  assert property (p);
endmodule
