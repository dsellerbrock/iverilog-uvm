// The bounded 16.11 lowering executes calls only at the final fixed endpoint.
module sva_match_item_intermediate;
  logic clk, a, b;
  a0: assert property (@(posedge clk)
        (a, $display("must not be dropped")) ##1 b) else ;
endmodule
