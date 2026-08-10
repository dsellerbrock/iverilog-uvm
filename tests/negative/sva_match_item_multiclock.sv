// Match-item action scheduling across an explicit clock-flow boundary is not
// represented by the bounded single-clock lowering.
module sva_match_item_multiclock;
  logic c1, c2, a, b;
  a0: assert property (@(posedge c1)
        (a, $display("must not be dropped")) ##1 @(posedge c2) b) else ;
endmodule
