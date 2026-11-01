// Direct sequence-property calls with arguments are covered by the positive
// 16.11 regression. Calls in implication properties remain outside the
// bounded lowering and must be refused loudly.
module sva_match_item_non_display;
  logic clk, a;
  task automatic action(input int value);
  endtask
  a0: assert property (@(posedge clk) (a, action(7)) |-> a) else ;
endmodule
