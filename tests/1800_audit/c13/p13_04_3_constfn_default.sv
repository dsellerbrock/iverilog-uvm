// IEEE 1800-2017 §13.4.3 (p. 328) / IEEE 1800-2023 §13.4.3 (p. 346):
// A constant function may have default argument values that are constant expressions.
module test;
  function int add_const(int a, int b = 10);
    return a + b;
  endfunction

  localparam int VAL = add_const(5);

  initial begin
    if (VAL === 15) $display("PASS 13.4.3 constant default argument VAL=%0d", VAL);
    else $fatal(1, "FAIL: expected VAL=15, got %0d", VAL);
  end
endmodule
