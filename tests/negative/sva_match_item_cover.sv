// Cover match actions need per-match cover dispatch; the assertion-only slice
// must reject this parsed call explicitly.
module sva_match_item_cover;
  logic clk, a;
  c0: cover property (@(posedge clk)
        (a, $display("must not be dropped")));
endmodule
