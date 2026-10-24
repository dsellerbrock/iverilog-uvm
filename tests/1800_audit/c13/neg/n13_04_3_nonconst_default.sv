// IEEE 1800-2017 §13.4.3 (p. 328) / IEEE 1800-2023 §13.4.3 (p. 346):
// Default argument values in a constant function shall be a constant expression.
module test;
  int dynamic_var = 42;
  function int add_dyn(int a, int b = dynamic_var);
    return a + b;
  endfunction

  // Illegal: dynamic_var is not a constant expression in a constant function call.
  localparam int VAL = add_dyn(5);

  initial $display("ACCEPTED n13_04_3_nonconst_default VAL=%0d", VAL);
endmodule
