// p32: G31 — chained enum method on function return value
// e.g. next_e(A).name() — fix in elab_expr.cc subject_expr_ block
typedef enum { IDLE, RUN, DONE } state_t;
function automatic state_t next_s(state_t s);
  return s.next();
endfunction
module top;
  initial begin
    automatic state_t s = RUN;
    automatic string nm = next_s(s).name();
    if (nm == "DONE")
      $display("PASS: chained enum method p32");
    else
      $display("FAIL: expected DONE got %s", nm);
    $finish;
  end
endmodule
