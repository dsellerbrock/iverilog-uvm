interface match_item_arg_if(input logic clk);
  logic hit;
  sequence bad_match;
    @(posedge clk) (hit, record_hit(1));
  endsequence
  cover property (bad_match);

  function automatic void record_hit(int value);
  endfunction
endinterface

module sv_sva_cover_match_item_arg_fail;
  logic clk = 0;
  match_item_arg_if pins(clk);
endmodule
