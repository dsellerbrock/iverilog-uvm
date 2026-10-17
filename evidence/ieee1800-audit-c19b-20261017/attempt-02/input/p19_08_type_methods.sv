module top;
  bit v;
  covergroup cg; coverpoint v { bins lo = {0}; bins hi = {1}; } endgroup
  cg g = new;
  initial begin v = 1; g.sample(); $display("INFO type_cg=%f type_cp=%f", cg::get_coverage(), cg::v::get_coverage()); end
endmodule
