// A ranged endpoint can produce several simultaneous match obligations; this
// implementation must reject it explicitly until per-match action dispatch is
// represented, rather than collapsing or dropping the call.
module sva_match_item_ranged;
  logic clk, a, b;
  a0: assert property (@(posedge clk)
        a ##[1:2] (b, $display("must not be dropped"))) else ;
endmodule
