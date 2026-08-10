// A call inside a sequence-combinator tree is outside the bounded flat slice.
module sva_match_item_tree;
  logic clk, a, b;
  a0: assert property (@(posedge clk)
        (a, $display("must not be dropped")) and b) else ;
endmodule
