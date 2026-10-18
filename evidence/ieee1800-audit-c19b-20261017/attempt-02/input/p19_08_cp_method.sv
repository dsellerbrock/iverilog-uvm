module top;
  bit v;
  covergroup cg; coverpoint v { bins lo = {0}; bins hi = {1}; } endgroup
  cg g = new;
  initial begin v = 1; g.sample(); $display("INFO cp_inst=%f", g.v.get_inst_coverage()); end
endmodule
