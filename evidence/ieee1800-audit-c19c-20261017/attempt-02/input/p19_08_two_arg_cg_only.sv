module top;
  int v, cov, tot;
  covergroup cg (int hi, ref int x); cp: coverpoint x { bins b[] = {[0:hi]}; } endgroup
  cg g = new(1, v);
  initial begin v = 0; g.sample(); void'(g.get_inst_coverage(cov, tot));
    $display("INFO cg_inst cov=%0d tot=%0d", cov, tot); end
endmodule
