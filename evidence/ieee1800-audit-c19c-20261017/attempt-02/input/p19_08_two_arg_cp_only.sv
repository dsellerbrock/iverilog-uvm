module top;
  bit v; int cov, tot;
  covergroup cg; cp: coverpoint v { bins lo = {0}; bins hi = {1}; } endgroup
  cg g = new;
  initial begin v = 1; g.sample(); void'(g.cp.get_inst_coverage(cov, tot));
    $display("INFO cp_inst cov=%0d tot=%0d", cov, tot); end
endmodule
