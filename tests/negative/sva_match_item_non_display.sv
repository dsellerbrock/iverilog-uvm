// Sequence match-item calls are permitted only at the end of a successful
// nonempty match. An argument-bearing task call on an intermediate step must
// remain visible and be refused loudly.
module sva_match_item_non_display;
  logic clk, a, b;
  task automatic action(input int value);
  endtask
  a0: assert property (@(posedge clk) (a, action(7)) ##1 b) else ;
endmodule
