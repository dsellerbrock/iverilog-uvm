// IEEE 1800-2017/2023 19.8: get_coverage and get_inst_coverage take no
// arguments or two ref int arguments.
module top;
  int covered, total;
  bit [7:0] narrow;
  real r;
  covergroup cg with function sample(bit p);
    cp: coverpoint p;
  endgroup
  cg c = new;
  initial begin
    r = c.get_coverage(covered);
    r = c.cp.get_coverage(covered, total, total);
    r = c.cp.get_inst_coverage(narrow, total);
    r = c.get_inst_coverage(covered, 5);
    c.cp.get_coverage(covered);
  end
endmodule
