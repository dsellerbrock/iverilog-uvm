// Repetition of a call-bearing match item is parsed, then refused by the
// bounded semantic validator with one targeted diagnostic.
module sva_match_item_repeated;
  logic clk, a;
  a0: assert property (@(posedge clk)
        (a, $display("must not be duplicated"))[*2]) else ;
endmodule
