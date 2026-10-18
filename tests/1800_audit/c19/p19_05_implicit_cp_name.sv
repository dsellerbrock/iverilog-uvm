module top;
  bit [1:0] v; covergroup cg; coverpoint v { bins b[] = {[0:3]}; } endgroup
  cg g = new;
  initial begin v = 1; g.sample();
    $display("%s 19.5.implicit_cp_name cov=%f", (g.v.get_inst_coverage() > 24.9 && g.v.get_inst_coverage() < 25.1) ? "PASS" : "FAIL", g.v.get_inst_coverage()); end
endmodule
