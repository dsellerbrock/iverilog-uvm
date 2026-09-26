// A function's name denotes its implicit return variable (IEEE
// 1800-2017/2023 13.4.1), which scope randomization may randomize (18.12).
// OpenTitan lc_ctrl_env_pkg::get_random_token() does exactly this; a zero
// token made the lc_ctrl smoke test hash the wrong value.
package tok_pkg;
  typedef logic [127:0] tok_t;
  function automatic tok_t expr_form();
    if (!std::randomize(expr_form)) $display("FAILED randomize");
  endfunction
  function automatic int stmt_form();
    std::randomize(stmt_form);
  endfunction
  function automatic bit [7:0] with_form();
    if (!std::randomize(with_form) with { with_form inside {[8'h10:8'h1f]}; })
      $display("FAILED randomize with");
  endfunction
endpackage

module test;
  tok_pkg::tok_t a, b;
  int i, j, distinct = 0;
  bit [7:0] w;
  bit failed = 0;
  initial begin
    repeat (20) begin
      a = tok_pkg::expr_form(); b = tok_pkg::expr_form();
      if ($isunknown(a) || $isunknown(b) || a == b) failed = 1;
      i = tok_pkg::stmt_form(); j = tok_pkg::stmt_form();
      if (i != j) distinct++;
      w = tok_pkg::with_form();
      if (!(w inside {[8'h10:8'h1f]})) failed = 1;
    end
    if (distinct < 15) failed = 1;
    if (failed) $display("FAILED a=%h b=%h distinct=%0d w=%h", a, b, distinct, w);
    else $display("PASSED");
  end
endmodule
