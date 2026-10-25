module sv_class_handle_clockvar_to_integral_assignment_fail;
  logic clk, q;
  class c; endclass
  c object;
  clocking cb @(posedge clk);
    output q;
  endclocking

  initial cb.q <= object;
endmodule
