// IEEE 1800-2017 §13.4.3 (p. 327) / IEEE 1800-2023 §13.4.3 (p. 346):
// A void function shall not be a constant function.
module test;
  function void side_effect(int a);
    int x;
    x = a;
  endfunction

  function int cf(int a);
    side_effect(a);
    return a + 1;
  endfunction

  // Illegal: a constant function cannot invoke a void function.
  localparam int VAL = cf(5);

  initial $display("ACCEPTED n13_04_3_void_constfn VAL=%0d", VAL);
endmodule
