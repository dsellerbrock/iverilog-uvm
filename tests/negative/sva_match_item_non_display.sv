// The first executable slice accepts direct $display only. Other legal
// sequence-match subroutine calls must remain visible and be refused loudly.
module sva_match_item_non_display;
  logic clk, a;
  task automatic action(input int value);
  endtask
  a0: assert property (@(posedge clk) (a, action(7))) else ;
endmodule
