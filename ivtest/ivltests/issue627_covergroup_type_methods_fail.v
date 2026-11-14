// IEEE 1800-2017/2023 19.8: the static get_coverage of a covergroup,
// coverpoint or cross type takes no arguments or two ref int arguments.
module top;
  int covered, total;
  bit [7:0] narrow;
  real r;
  covergroup cg with function sample(bit p);
    cp: coverpoint p;
  endgroup
  cg c = new;
  initial begin
    r = cg::get_coverage(covered);
    r = cg::cp::get_coverage(narrow, total);
    cg::cp::get_coverage(covered, total, total);
    void'(cg::get_coverage(covered, 5));
  end
endmodule
