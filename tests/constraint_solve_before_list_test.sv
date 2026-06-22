// Regression: a "solve ... before ..." ordering directive with a comma-separated
// variable list, e.g.
//   solve speed_mode before tlow, t_r, t_f, thd_sta, t_buf, thigh;
// (OpenTitan i2c_host_perf_vseq.sv). The list form lived in constraint_block_item
// but was shadowed/unreachable due to a conflict with the single-expression form
// in constraint_expression, so any solve-before with a comma list (even alone)
// failed to parse. A dedicated solve_expr_list now makes the list form work both
// at the constraint-block top level and nested inside foreach/if bodies. The
// directive only affects solver variable ordering (not modeled), so it is
// parsed and discarded.
class c;
  rand int speed_mode, tlow, t_r, t_f, thd, tsu;
  constraint timing_c {
    speed_mode inside {[0:3]};
    if (speed_mode > 0) { thd == 5; } else { thd == 1; }
    solve speed_mode before tlow, t_r, t_f, thd, tsu;
    solve t_r before tlow;
  }
endclass
module top;
  initial begin
    c o = new();
    if (o.randomize()) $display("PASS");
    else $display("FAIL");
  end
endmodule
