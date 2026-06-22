// Regression: two covergroup parse gaps that blocked OpenTitan coverage builds
// (i2c, sysrst_ctrl, spi_host *_cov.sv), both parse-and-ignore (coverage no-op):
//   1. Transition bins with comma-separated value-sets at each "=>" step, e.g.
//        bins t = (A, B => C, D => E);
//      (i2c_protocol_cov.sv). transition_list previously only accepted a single
//      expression on each side of "=>".
//   2. A "cross ... iff (expr)" guard (sysrst_ctrl_env_cov.sv). No cross form
//      accepted an iff guard, so the cross failed to parse and desynced the
//      covergroup body, cascading into thousands of spurious syntax errors.
//   3. A coverpoint-level "iff (expr)" guard, e.g. "coverpoint x iff (en)"
//      (i2c_protocol_cov.sv). All three are discarded (coverage no-op).
module top;
  typedef enum { A, B, C, D, E, F } st_e;
  class c;
    st_e x, y;
    covergroup cg;
      cp_x: coverpoint x;
      cp_y: coverpoint y;
      cp_g: coverpoint x iff (x != F);
      tr: coverpoint x iff (x != F) {
        bins t = (A, B => C, D => E);
      }
      cr: cross cp_x, cp_y iff (x != F) {
        ignore_bins z = binsof(cp_x) intersect {0} && binsof(cp_y) intersect {0};
      }
    endgroup
    function new(); cg = new(); endfunction
    function int s(); return 7; endfunction
  endclass
  initial begin
    c o = new();
    if (o.s() == 7) $display("PASS");
    else $display("FAIL");
  end
endmodule
