module top;
  bit [7:0] v;
  covergroup cg; coverpoint v { bins t = { [100 +/- 2] }; bins p = { [50 +%- 10] }; bins o = {7}; } endgroup
  cg out = new, in = new;
  initial begin
    v = 97; out.sample(); v = 56; out.sample(); v = 98; in.sample(); v = 55; in.sample();
    $display("%s 19.5.tolerance_outside cov=%f", out.get_inst_coverage() < 0.01 ? "PASS" : "FAIL", out.get_inst_coverage());
    $display("%s 19.5.tolerance_inside cov=%f", (in.get_inst_coverage() > 66.6 && in.get_inst_coverage() < 66.7) ? "PASS" : "FAIL", in.get_inst_coverage());
  end
endmodule
