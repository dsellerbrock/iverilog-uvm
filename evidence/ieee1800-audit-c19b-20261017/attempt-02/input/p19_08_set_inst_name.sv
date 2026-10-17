module top;
  bit v;
  covergroup cg; coverpoint v; endgroup
  cg g = new;
  initial begin
    g.set_inst_name("inst_x");
    $display("%s 19.8.set_inst_name name=%s", g.option.name == "inst_x" ? "PASS" : "FAIL", g.option.name);
  end
endmodule
